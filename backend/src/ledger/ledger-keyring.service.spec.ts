import { Test, TestingModule } from '@nestjs/testing';
import { getAddress, keccak256, toUtf8Bytes, Wallet } from 'ethers';
import { LedgerKeyRingService } from './ledger-keyring.service';
import { CryptoModule } from '../crypto/crypto.module';
import { Eip712Service } from '../crypto/eip712.service';
import { DEFAULT_BASE_SEPOLIA_DOMAIN } from '../crypto/eip712.constants';
import { TreasuryActionApprovalParams } from '../crypto/interfaces/eip712.interface';
import { DEFAULT_MOCK_LEDGER_KEY, DEFAULT_DERIVATION_PATH } from './ledger.constants';

describe('LedgerKeyRingService', () => {
  let service: LedgerKeyRingService;
  let eip712Service: Eip712Service;

  const mockApprovalParams: TreasuryActionApprovalParams = {
    actionId: 'act_infra_annual_renewal_850',
    agent: '0x0000000000000000000000000000000000000002',
    recipient: '0x0000000000000000000000000000000000041C4E',
    token: '0x0000000000000000000000000000000000000999',
    amount: (850 * 1e6).toString(),
    nonce: '101',
    deadline: '1773081600',
    mandateHash: keccak256(toUtf8Bytes('MANDATE_V1')),
    riskScore: 78,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [CryptoModule],
      providers: [LedgerKeyRingService],
    }).compile();

    service = module.get<LedgerKeyRingService>(LedgerKeyRingService);
    eip712Service = module.get<Eip712Service>(Eip712Service);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('Device Status & Identity', () => {
    it('should report device status, derivation path, and address', async () => {
      const status = await service.getStatus();
      const expectedWallet = new Wallet(DEFAULT_MOCK_LEDGER_KEY);

      expect(status.connected).toBe(true);
      expect(status.mode).toBe('MOCK_HARDWARE');
      expect(status.address).toBe(getAddress(expectedWallet.address));
      expect(status.derivationPath).toBe(DEFAULT_DERIVATION_PATH);
      expect(status.keyRingInitialized).toBe(true);
    });

    it('should return the checksummed signer address', async () => {
      const address = await service.getSignerAddress();
      const expectedWallet = new Wallet(DEFAULT_MOCK_LEDGER_KEY);

      expect(address).toBe(getAddress(expectedWallet.address));
    });

    it('should allow mode switching', async () => {
      service.setMode('HEADLESS_CLI');
      const status = await service.getStatus();
      expect(status.mode).toBe('HEADLESS_CLI');

      service.setMode('MOCK_HARDWARE');
    });
  });

  describe('Clear-Signing Prompt Formatting', () => {
    it('should format human-readable clear-signing fields without blind signing', () => {
      const prompt = service.formatClearSignPrompt(mockApprovalParams);

      expect(prompt.title).toBe('CHAPTER 2 TREASURY ESCALATION');
      expect(prompt.digest).toBe(eip712Service.computeDigest(mockApprovalParams));

      // Amount field formatted to currency
      const amountField = prompt.fields.find((f) => f.label === 'Transfer Amount');
      expect(amountField).toBeDefined();
      expect(amountField?.value).toContain('$850.00');
      expect(amountField?.critical).toBe(true);

      // Recipient field
      const recipientField = prompt.fields.find((f) => f.label === 'Recipient');
      expect(recipientField).toBeDefined();
      expect(recipientField?.value).toBe(getAddress(mockApprovalParams.recipient));
      expect(recipientField?.critical).toBe(true);

      // Risk score warning
      const riskField = prompt.fields.find((f) => f.label === 'Risk Score');
      expect(riskField).toBeDefined();
      expect(riskField?.value).toContain('78 / 100 (HIGH RISK)');
      expect(riskField?.critical).toBe(true);
    });
  });

  describe('Escalated Action Signing & Verification', () => {
    it('should sign an escalated approval and produce valid EIP-712 signature', async () => {
      const result = await service.signApproval(mockApprovalParams);

      expect(result.signature).toBeDefined();
      expect(result.signature.startsWith('0x')).toBe(true);
      expect(result.signer).toBe(await service.getSignerAddress());
      expect(result.digest).toBe(eip712Service.computeDigest(mockApprovalParams));

      // Verify with Eip712Service directly
      const isValid = eip712Service.verifySignature(
        mockApprovalParams,
        result.signature,
        result.signer,
      );
      expect(isValid).toBe(true);

      // Verify recovered address matches signer
      const recovered = eip712Service.recoverSigner(mockApprovalParams, result.signature);
      expect(getAddress(recovered)).toBe(result.signer);
    });

    it('should generate an ABI-encoded payload decodable for Safe.execTransaction()', async () => {
      const result = await service.signApproval(mockApprovalParams);
      expect(result.encodedPayload.startsWith('0x')).toBe(true);

      const decoded = eip712Service.decodeEscalatedPayload(result.encodedPayload);
      expect(decoded.approval.actionId).toBe(mockApprovalParams.actionId);
      expect(decoded.approval.amount).toBe(mockApprovalParams.amount.toString());
      expect(decoded.approval.recipient).toBe(getAddress(mockApprovalParams.recipient));
      expect(decoded.signature).toBe(result.signature);
    });

    it('should verify signature via verifyLedgerSignature helper', async () => {
      const result = await service.signApproval(mockApprovalParams);

      const isVerified = await service.verifyLedgerSignature(
        mockApprovalParams,
        result.signature,
      );
      expect(isVerified).toBe(true);

      // Tampered payload
      const isTamperedVerified = await service.verifyLedgerSignature(
        { ...mockApprovalParams, amount: '900000000' },
        result.signature,
      );
      expect(isTamperedVerified).toBe(false);
    });
  });

  describe('Ledger Key Ring Protocol (LKRP) Secret Management', () => {
    it('should encrypt and decrypt an agent operational secret via AES-256-GCM', async () => {
      const keyName = 'AGENT_RELAYER_PRIVATE_KEY';
      const secretValue = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

      const encryptedSecret = await service.encryptSecret(keyName, secretValue);

      expect(encryptedSecret.keyName).toBe(keyName);
      expect(encryptedSecret.algorithm).toBe('AES-256-GCM');
      expect(encryptedSecret.ciphertext).not.toContain(secretValue);
      expect(encryptedSecret.ciphertext.split(':').length).toBe(3); // iv:authTag:ciphertext

      const decrypted = await service.decryptSecret(encryptedSecret);
      expect(decrypted).toBe(secretValue);
    });

    it('should track and list stored secrets in the key ring vault', async () => {
      await service.encryptSecret('AGENT_KEY_1', 'val1');
      await service.encryptSecret('AGENT_KEY_2', 'val2');

      const keys = await service.listKeys();
      expect(keys).toContain('AGENT_KEY_1');
      expect(keys).toContain('AGENT_KEY_2');
    });

    it('should fail decryption if the ciphertext or authentication tag is tampered with', async () => {
      const secret = await service.encryptSecret('TAMPER_TEST', 'sensitive_data');
      const [iv, authTag, ciphertext] = secret.ciphertext.split(':');

      // Tampered ciphertext
      const tamperedSecret = {
        ...secret,
        ciphertext: `${iv}:${authTag}:${ciphertext.slice(0, -2)}ff`,
      };

      await expect(service.decryptSecret(tamperedSecret)).rejects.toThrow();
    });
  });
});
