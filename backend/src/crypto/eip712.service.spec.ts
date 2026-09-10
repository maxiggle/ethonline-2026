import { Test, TestingModule } from '@nestjs/testing';
import { HDNodeWallet, Wallet, getAddress, keccak256, toUtf8Bytes, AbiCoder } from 'ethers';
import { Eip712Service } from './eip712.service';
import {
  DEFAULT_BASE_SEPOLIA_DOMAIN,
  ACTION_APPROVAL_TYPE_STRING,
  EIP712_ACTION_APPROVAL_TYPES,
} from './eip712.constants';
import { TreasuryActionApprovalParams } from './interfaces/eip712.interface';

describe('Eip712Service', () => {
  let service: Eip712Service;
  let signerWallet: HDNodeWallet;
  let unauthorizedWallet: HDNodeWallet;

  const mockParams: TreasuryActionApprovalParams = {
    actionId: 'act_alchemy_annual_renewal_001',
    agent: '0x1111111111111111111111111111111111111111',
    recipient: '0x0000000000000000000000000000000000041c4e',
    token: '0x9999999999999999999999999999999999999999',
    amount: '850000000',
    nonce: '101',
    deadline: '1773081600',
    mandateHash: keccak256(toUtf8Bytes('MANDATE_V1')),
    riskScore: 78,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [Eip712Service],
    }).compile();

    service = module.get<Eip712Service>(Eip712Service);
    signerWallet = Wallet.createRandom();
    unauthorizedWallet = Wallet.createRandom();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('Domain Separator and Typehash', () => {
    it('should calculate domain separator matching the contract specification', () => {
      const computedDomainSeparator = service.computeDomainSeparator(DEFAULT_BASE_SEPOLIA_DOMAIN);

      const eip712DomainTypehash = keccak256(
        toUtf8Bytes(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)',
        ),
      );
      const expectedDomainSeparator = keccak256(
        AbiCoder.defaultAbiCoder().encode(
          ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
          [
            eip712DomainTypehash,
            keccak256(toUtf8Bytes(DEFAULT_BASE_SEPOLIA_DOMAIN.name)),
            keccak256(toUtf8Bytes(DEFAULT_BASE_SEPOLIA_DOMAIN.version)),
            DEFAULT_BASE_SEPOLIA_DOMAIN.chainId,
            DEFAULT_BASE_SEPOLIA_DOMAIN.verifyingContract,
          ],
        ),
      );

      expect(computedDomainSeparator).toEqual(expectedDomainSeparator);
    });

    it('should conform to the ACTION_APPROVAL_TYPEHASH specification in Chapter2Guard', () => {
      const typehash = keccak256(toUtf8Bytes(ACTION_APPROVAL_TYPE_STRING));
      expect(typehash).toBeDefined();
      expect(typehash.length).toEqual(66);
    });
  });

  describe('Typed Data Generation & Digest', () => {
    it('should generate compliant EIP-712 typed data envelope', () => {
      const typedData = service.generateTypedData(mockParams);

      expect(typedData.primaryType).toEqual('TreasuryActionApproval');
      expect(typedData.domain.name).toEqual('Chapter2');
      expect(typedData.domain.chainId).toEqual(84532n);
      expect(typedData.message.actionId).toEqual(mockParams.actionId);
      expect(typedData.message.amount).toEqual(850000000n);
      expect(typedData.message.riskScore).toEqual(78);
    });

    it('should compute the 32-byte signing digest identically to direct hashing', () => {
      const digest = service.computeDigest(mockParams);
      expect(digest).toMatch(/^0x[a-fA-F0-9]{64}$/);
    });
  });

  describe('Signature Verification', () => {
    it('should sign typed data and verify the signature for the expected signer', async () => {
      const signature = await signerWallet.signTypedData(
        {
          name: DEFAULT_BASE_SEPOLIA_DOMAIN.name,
          version: DEFAULT_BASE_SEPOLIA_DOMAIN.version,
          chainId: DEFAULT_BASE_SEPOLIA_DOMAIN.chainId,
          verifyingContract: DEFAULT_BASE_SEPOLIA_DOMAIN.verifyingContract,
        },
        EIP712_ACTION_APPROVAL_TYPES,
        {
          actionId: mockParams.actionId,
          agent: getAddress(mockParams.agent),
          recipient: getAddress(mockParams.recipient),
          token: getAddress(mockParams.token),
          amount: BigInt(mockParams.amount),
          nonce: BigInt(mockParams.nonce),
          deadline: BigInt(mockParams.deadline),
          mandateHash: mockParams.mandateHash,
          riskScore: mockParams.riskScore,
        },
      );

      const isValid = service.verifySignature(
        mockParams,
        signature,
        signerWallet.address,
      );

      expect(isValid).toBe(true);
    });

    it('should recover the exact signer address from the signature', async () => {
      const signature = await signerWallet.signTypedData(
        {
          name: DEFAULT_BASE_SEPOLIA_DOMAIN.name,
          version: DEFAULT_BASE_SEPOLIA_DOMAIN.version,
          chainId: DEFAULT_BASE_SEPOLIA_DOMAIN.chainId,
          verifyingContract: DEFAULT_BASE_SEPOLIA_DOMAIN.verifyingContract,
        },
        EIP712_ACTION_APPROVAL_TYPES,
        {
          actionId: mockParams.actionId,
          agent: getAddress(mockParams.agent),
          recipient: getAddress(mockParams.recipient),
          token: getAddress(mockParams.token),
          amount: BigInt(mockParams.amount),
          nonce: BigInt(mockParams.nonce),
          deadline: BigInt(mockParams.deadline),
          mandateHash: mockParams.mandateHash,
          riskScore: mockParams.riskScore,
        },
      );

      const recovered = service.recoverSigner(mockParams, signature);
      expect(getAddress(recovered)).toEqual(getAddress(signerWallet.address));
    });

    it('should reject when signed by an unauthorized signer', async () => {
      const signature = await unauthorizedWallet.signTypedData(
        {
          name: DEFAULT_BASE_SEPOLIA_DOMAIN.name,
          version: DEFAULT_BASE_SEPOLIA_DOMAIN.version,
          chainId: DEFAULT_BASE_SEPOLIA_DOMAIN.chainId,
          verifyingContract: DEFAULT_BASE_SEPOLIA_DOMAIN.verifyingContract,
        },
        EIP712_ACTION_APPROVAL_TYPES,
        {
          actionId: mockParams.actionId,
          agent: getAddress(mockParams.agent),
          recipient: getAddress(mockParams.recipient),
          token: getAddress(mockParams.token),
          amount: BigInt(mockParams.amount),
          nonce: BigInt(mockParams.nonce),
          deadline: BigInt(mockParams.deadline),
          mandateHash: mockParams.mandateHash,
          riskScore: mockParams.riskScore,
        },
      );

      const isValid = service.verifySignature(
        mockParams,
        signature,
        signerWallet.address,
      );

      expect(isValid).toBe(false);
    });

    it('should reject signature if any parameter is tampered with', async () => {
      const signature = await signerWallet.signTypedData(
        {
          name: DEFAULT_BASE_SEPOLIA_DOMAIN.name,
          version: DEFAULT_BASE_SEPOLIA_DOMAIN.version,
          chainId: DEFAULT_BASE_SEPOLIA_DOMAIN.chainId,
          verifyingContract: DEFAULT_BASE_SEPOLIA_DOMAIN.verifyingContract,
        },
        EIP712_ACTION_APPROVAL_TYPES,
        {
          actionId: mockParams.actionId,
          agent: getAddress(mockParams.agent),
          recipient: getAddress(mockParams.recipient),
          token: getAddress(mockParams.token),
          amount: BigInt(mockParams.amount),
          nonce: BigInt(mockParams.nonce),
          deadline: BigInt(mockParams.deadline),
          mandateHash: mockParams.mandateHash,
          riskScore: mockParams.riskScore,
        },
      );

      // Tampered amount
      expect(
        service.verifySignature(
          { ...mockParams, amount: '900000000' },
          signature,
          signerWallet.address,
        ),
      ).toBe(false);

      // Tampered recipient
      expect(
        service.verifySignature(
          { ...mockParams, recipient: '0x2222222222222222222222222222222222222222' },
          signature,
          signerWallet.address,
        ),
      ).toBe(false);

      // Tampered nonce
      expect(
        service.verifySignature(
          { ...mockParams, nonce: '102' },
          signature,
          signerWallet.address,
        ),
      ).toBe(false);

      // Tampered risk score
      expect(
        service.verifySignature(
          { ...mockParams, riskScore: 20 },
          signature,
          signerWallet.address,
        ),
      ).toBe(false);
    });
  });

  describe('Safe Escalation ABI Payload Encoding', () => {
    it('should encode and decode escalated payload for Chapter2Guard.checkTransaction()', async () => {
      const mockSignature =
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b';

      const encoded = service.encodeEscalatedPayload(mockParams, mockSignature);
      expect(encoded.startsWith('0x')).toBe(true);

      const decoded = service.decodeEscalatedPayload(encoded);

      expect(decoded.approval.actionId).toEqual(mockParams.actionId);
      expect(decoded.approval.agent).toEqual(getAddress(mockParams.agent));
      expect(decoded.approval.recipient).toEqual(getAddress(mockParams.recipient));
      expect(decoded.approval.token).toEqual(getAddress(mockParams.token));
      expect(decoded.approval.amount).toEqual(mockParams.amount.toString());
      expect(decoded.approval.nonce).toEqual(mockParams.nonce.toString());
      expect(decoded.approval.deadline).toEqual(mockParams.deadline.toString());
      expect(decoded.approval.mandateHash).toEqual(mockParams.mandateHash);
      expect(decoded.approval.riskScore).toEqual(mockParams.riskScore);
      expect(decoded.signature).toEqual(mockSignature);
    });

    it('should cross-verify with Foundry test vector from Chapter2Guard.t.sol', async () => {
      const foundryPrivateKey =
        '0x00000000000000000000000000000000000000000000000000000000000a11ce';
      const foundryWallet = new Wallet(foundryPrivateKey);

      const foundryParams: TreasuryActionApprovalParams = {
        actionId: 'act_alchemy_annual_renewal_001',
        agent: '0x0000000000000000000000000000000000000002',
        recipient: '0x0000000000000000000000000000000000041C4E',
        token: '0x0000000000000000000000000000000000000999',
        amount: (850 * 1e6).toString(),
        nonce: '101',
        deadline: '1773081600',
        mandateHash: keccak256(toUtf8Bytes('MANDATE_V1')),
        riskScore: 78,
      };

      const signature = await foundryWallet.signTypedData(
        {
          name: DEFAULT_BASE_SEPOLIA_DOMAIN.name,
          version: DEFAULT_BASE_SEPOLIA_DOMAIN.version,
          chainId: DEFAULT_BASE_SEPOLIA_DOMAIN.chainId,
          verifyingContract: DEFAULT_BASE_SEPOLIA_DOMAIN.verifyingContract,
        },
        EIP712_ACTION_APPROVAL_TYPES,
        {
          actionId: foundryParams.actionId,
          agent: getAddress(foundryParams.agent),
          recipient: getAddress(foundryParams.recipient),
          token: getAddress(foundryParams.token),
          amount: BigInt(foundryParams.amount),
          nonce: BigInt(foundryParams.nonce),
          deadline: BigInt(foundryParams.deadline),
          mandateHash: foundryParams.mandateHash,
          riskScore: foundryParams.riskScore,
        },
      );

      // Verify recovered signer matches humanOwner in Foundry
      const recovered = service.recoverSigner(foundryParams, signature);
      expect(getAddress(recovered)).toEqual(getAddress(foundryWallet.address));

      // Verify validation passes
      expect(
        service.verifySignature(foundryParams, signature, foundryWallet.address),
      ).toBe(true);

      // Encode escalated payload
      const encodedPayload = service.encodeEscalatedPayload(foundryParams, signature);
      const decodedPayload = service.decodeEscalatedPayload(encodedPayload);

      expect(decodedPayload.approval.actionId).toEqual(foundryParams.actionId);
      expect(decodedPayload.approval.amount).toEqual((850 * 1e6).toString());
      expect(decodedPayload.signature).toEqual(signature);
    });
  });
});
