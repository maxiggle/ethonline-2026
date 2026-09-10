import { Test, TestingModule } from '@nestjs/testing';
import { Wallet, getAddress } from 'ethers';
import { LedgerController } from './ledger.controller';
import { LedgerKeyRingService } from './ledger-keyring.service';
import { Eip712Service } from '../crypto/eip712.service';
import { SignApprovalDto } from './dto/sign-approval.dto';
import { DEFAULT_BASE_SEPOLIA_DOMAIN } from '../crypto/eip712.constants';
import { DEFAULT_MOCK_LEDGER_KEY } from './ledger.constants';

describe('LedgerController', () => {
  let controller: LedgerController;
  let service: LedgerKeyRingService;
  const expectedSigner = getAddress(new Wallet(DEFAULT_MOCK_LEDGER_KEY).address);

  const validApprovalDto: SignApprovalDto = {
    actionId: 'act-ctrl-001',
    agent: '0x1111111111111111111111111111111111111111',
    recipient: '0x0000000000000000000000000000000000041c4e',
    token: '0x0000000000000000000000000000000000041c4e',
    amount: '150000000',
    nonce: 1,
    deadline: 1800000000,
    mandateHash: '0x71e847c234a413ba1179ab846059c402aaefd685ad83a8b2b7161b9a95cbba84',
    riskScore: 75,
    domain: DEFAULT_BASE_SEPOLIA_DOMAIN,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [LedgerController],
      providers: [LedgerKeyRingService, Eip712Service],
    }).compile();

    controller = module.get<LedgerController>(LedgerController);
    service = module.get<LedgerKeyRingService>(LedgerKeyRingService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should return device status and connection telemetry', async () => {
    const status = await controller.getStatus();
    expect(status.connected).toBe(true);
    expect(status.mode).toBe('MOCK_HARDWARE');
    expect(status.model).toBeDefined();
    expect(status.address).toBe(expectedSigner);
  });

  it('should return the signer address', async () => {
    const res = await controller.getSignerAddress();
    expect(res.address).toBe(expectedSigner);
  });

  it('should format clear-sign prompt correctly', () => {
    const prompt = controller.formatClearSignPrompt(validApprovalDto);
    expect(prompt.title).toBeDefined();
    expect(prompt.fields.some((f) => f.label === 'Transfer Amount')).toBe(true);
    expect(prompt.fields.some((f) => f.label === 'Recipient')).toBe(true);
  });

  it('should sign approval payload and return valid signature and encodedPayload', async () => {
    const result = await controller.signApproval(validApprovalDto);
    expect(result.signature).toMatch(/^0x[a-fA-F0-9]{130}$/);
    expect(result.signer).toBe(expectedSigner);
    expect(result.encodedPayload).toMatch(/^0x/);
  });

  it('should list keys in the key ring vault', async () => {
    const res = await controller.listKeys();
    expect(res).toBeDefined();
    expect(Array.isArray(res.keys)).toBe(true);
    expect(res.count).toBe(res.keys.length);
  });
});
