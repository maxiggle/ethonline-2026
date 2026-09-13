import { Test, TestingModule } from '@nestjs/testing';
import { OnChainExecutorService } from './on-chain-executor.service';

describe('OnChainExecutorService (Tested with Actual On-Chain Data)', () => {
  let service: OnChainExecutorService;

  const realSafeAddress = process.env.SAFE_ADDRESS!;
  const realGuardAddress = process.env.GUARD_ADDRESS!;

  // Real mined Base Sepolia transactions
  const GUARD_DEPLOY_TX = '0x86fe4afdb35ffafdc67fba833eeb4b68657e1539564f01c08d431106402347c5';
  const SAFE_DEPLOY_TX = '0x67c5cfaf8e42dfb22bc41b6f4be9b7285a5a0e3925ef5288cd5988b791281766';

  jest.setTimeout(45000);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [OnChainExecutorService],
    }).compile();

    service = module.get<OnChainExecutorService>(OnChainExecutorService);
  });

  it('should initialize successfully with live Base Sepolia contracts', () => {
    expect(service).toBeDefined();
    expect(service.safeAddress).toBe(realSafeAddress);
    expect(service.guardAddress).toBe(realGuardAddress);
    expect(service.chainId).toBe(84532);
    expect(service.safeContract).toBeDefined();
    expect(service.guardContract).toBeDefined();
    expect(service.provider).toBeDefined();
  });

  describe('Read-only (no signing key)', () => {
    it('initializes without RELAYER_PRIVATE_KEY', () => {
      const orig = process.env.RELAYER_PRIVATE_KEY;
      delete process.env.RELAYER_PRIVATE_KEY;
      try {
        expect(() => new OnChainExecutorService()).not.toThrow();
      } finally {
        if (orig !== undefined) {
          process.env.RELAYER_PRIVATE_KEY = orig;
        }
      }
    });

    it('exposes no transaction-broadcasting methods', () => {
      const methods = service as unknown as Record<string, unknown>;
      expect(methods.executeAutonomousPayment).toBeUndefined();
      expect(methods.executeEscalatedPayment).toBeUndefined();
      expect(methods.setAutonomousAgent).toBeUndefined();
      expect(methods.relayerWallet).toBeUndefined();
    });
  });

  describe('Environment Variable Validations (Strict Zero-Fallback Policy)', () => {
    it('should throw immediately if RPC_URL is missing', () => {
      const orig = process.env.RPC_URL;
      delete process.env.RPC_URL;
      try {
        expect(() => new OnChainExecutorService()).toThrow('Missing required environment variable: RPC_URL');
      } finally {
        process.env.RPC_URL = orig;
      }
    });

    it('should throw immediately if SAFE_ADDRESS is missing', () => {
      const orig = process.env.SAFE_ADDRESS;
      delete process.env.SAFE_ADDRESS;
      try {
        expect(() => new OnChainExecutorService()).toThrow('Missing required environment variable: SAFE_ADDRESS');
      } finally {
        process.env.SAFE_ADDRESS = orig;
      }
    });

    it('should throw immediately if GUARD_ADDRESS is missing', () => {
      const orig = process.env.GUARD_ADDRESS;
      delete process.env.GUARD_ADDRESS;
      try {
        expect(() => new OnChainExecutorService()).toThrow('Missing required environment variable: GUARD_ADDRESS');
      } finally {
        process.env.GUARD_ADDRESS = orig;
      }
    });

    it('should throw immediately if CHAIN_ID is missing', () => {
      const orig = process.env.CHAIN_ID;
      delete process.env.CHAIN_ID;
      try {
        expect(() => new OnChainExecutorService()).toThrow('Missing required environment variable: CHAIN_ID');
      } finally {
        process.env.CHAIN_ID = orig;
      }
    });
  });

  describe('Actual On-Chain Contract State Verification', () => {
    it('should query live Chapter2Guard contract configuration directly from Base Sepolia', async () => {
      const guardConfig = await service.getOnChainGuardConfig();

      expect(guardConfig.maxAutonomousAmount).toBe(100000000n); // $100
      expect(guardConfig.dailyAutonomousLimit).toBe(500000000n); // $500
      expect(guardConfig.remainingDailyBudget).toBeGreaterThanOrEqual(0n);
      expect(guardConfig.safeAddress.toLowerCase()).toBe(realSafeAddress.toLowerCase());

      // Verify recipient whitelists on-chain
      const isWhitelisted = await service.guardContract.isApprovedRecipient(
        '0x0000000000000000000000000000000000041c4e',
      );
      expect(isWhitelisted).toBe(true);

      const isUnapproved = await service.guardContract.isApprovedRecipient(
        '0x9999999999999999999999999999999999999999',
      );
      expect(isUnapproved).toBe(false);
    }, 15000);

    it('should query live Safe contract state directly from Base Sepolia', async () => {
      const safeConfig = await service.getOnChainSafeConfig();

      expect(safeConfig.guardAddress.toLowerCase()).toBe(realGuardAddress.toLowerCase());
      expect(safeConfig.owner).toMatch(/^0x[a-fA-F0-9]{40}$/);
      expect(safeConfig.nonce).toBeGreaterThanOrEqual(0n);
    }, 15000);
  });

  describe('Actual On-Chain Transaction Receipt Verification (verifyTransaction)', () => {
    it('should verify real Chapter2Guard deployment receipt on Base Sepolia', async () => {
      const result = await service.verifyTransaction(GUARD_DEPLOY_TX);

      expect(result.verified).toBe(true);
      expect(result.receipt).toBeDefined();
      expect(result.receipt?.status).toBe(1);
      expect(result.receipt?.blockNumber).toBe(46605025);
    });

    it('should verify real MockSafe deployment receipt on Base Sepolia', async () => {
      const result = await service.verifyTransaction(SAFE_DEPLOY_TX);

      expect(result.verified).toBe(true);
      expect(result.receipt).toBeDefined();
      expect(result.receipt?.status).toBe(1);
    });

    it('should return verified: false for invalid or unconfirmed transaction hashes', async () => {
      const invalidHash = '0x0000000000000000000000000000000000000000000000000000000000000000';
      const result = await service.verifyTransaction(invalidHash);

      expect(result.verified).toBe(false);
      expect(result.error).toContain('Transaction receipt not found');
    });

    it('should reject malformed non-hex hashes gracefully', async () => {
      const result = await service.verifyTransaction('not-a-hash');
      expect(result.verified).toBe(false);
      expect(result.error).toContain('Invalid transaction hash format');
    });
  });
});
