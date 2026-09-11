import { Test, TestingModule } from '@nestjs/testing';
import { OnChainExecutorService } from './on-chain-executor.service';
import { ActionStoreService } from '../actions/action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { Eip712Service } from '../crypto/eip712.service';
import { EventsGateway } from '../gateway/events.gateway';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { Server } from 'socket.io';

describe('OnChainExecutorService (Tested with Actual On-Chain Data)', () => {
  let service: OnChainExecutorService;
  let actionStore: ActionStoreService;
  let gateway: EventsGateway;
  let mockServer: Partial<Server>;

  const realSafeAddress = process.env.SAFE_ADDRESS!;
  const realGuardAddress = process.env.GUARD_ADDRESS!;
  const realRelayerKey = process.env.RELAYER_PRIVATE_KEY!;
  const realRpcUrl = process.env.RPC_URL!;
  const realChainId = process.env.CHAIN_ID!;

  // Real mined Base Sepolia transactions
  const GUARD_DEPLOY_TX = '0x86fe4afdb35ffafdc67fba833eeb4b68657e1539564f01c08d431106402347c5';
  const SAFE_DEPLOY_TX = '0x67c5cfaf8e42dfb22bc41b6f4be9b7285a5a0e3925ef5288cd5988b791281766';

  jest.setTimeout(45000);

  beforeEach(async () => {
    mockServer = {
      emit: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OnChainExecutorService,
        ActionStoreService,
        PolicyEngineService,
        Eip712Service,
        EventsGateway,
      ],
    }).compile();

    service = module.get<OnChainExecutorService>(OnChainExecutorService);
    actionStore = module.get<ActionStoreService>(ActionStoreService);
    gateway = module.get<EventsGateway>(EventsGateway);
    gateway.server = mockServer as Server;
  });

  it('should initialize successfully with live Base Sepolia contracts', () => {
    expect(service).toBeDefined();
    expect(service.safeAddress).toBe(realSafeAddress);
    expect(service.guardAddress).toBe(realGuardAddress);
    expect(service.chainId).toBe(84532);
    expect(service.safeContract).toBeDefined();
    expect(service.guardContract).toBeDefined();
    expect(service.provider).toBeDefined();
    expect(service.relayerWallet.address).toBe('0x988B225185b516DEF12A7Ec841abae9072ef4EE8');
  });

  describe('Environment Variable Validations (Strict Zero-Fallback Policy)', () => {
    it('should throw immediately if RPC_URL is missing', () => {
      const orig = process.env.RPC_URL;
      delete process.env.RPC_URL;
      try {
        expect(() => {
          new OnChainExecutorService(actionStore, {} as any, {} as any, gateway);
        }).toThrow('Missing required environment variable: RPC_URL');
      } finally {
        process.env.RPC_URL = orig;
      }
    });

    it('should throw immediately if SAFE_ADDRESS is missing', () => {
      const orig = process.env.SAFE_ADDRESS;
      delete process.env.SAFE_ADDRESS;
      try {
        expect(() => {
          new OnChainExecutorService(actionStore, {} as any, {} as any, gateway);
        }).toThrow('Missing required environment variable: SAFE_ADDRESS');
      } finally {
        process.env.SAFE_ADDRESS = orig;
      }
    });

    it('should throw immediately if GUARD_ADDRESS is missing', () => {
      const orig = process.env.GUARD_ADDRESS;
      delete process.env.GUARD_ADDRESS;
      try {
        expect(() => {
          new OnChainExecutorService(actionStore, {} as any, {} as any, gateway);
        }).toThrow('Missing required environment variable: GUARD_ADDRESS');
      } finally {
        process.env.GUARD_ADDRESS = orig;
      }
    });

    it('should throw immediately if RELAYER_PRIVATE_KEY is missing', () => {
      const orig = process.env.RELAYER_PRIVATE_KEY;
      delete process.env.RELAYER_PRIVATE_KEY;
      try {
        expect(() => {
          new OnChainExecutorService(actionStore, {} as any, {} as any, gateway);
        }).toThrow('Missing required environment variable: RELAYER_PRIVATE_KEY');
      } finally {
        process.env.RELAYER_PRIVATE_KEY = orig;
      }
    });

    it('should throw immediately if CHAIN_ID is missing', () => {
      const orig = process.env.CHAIN_ID;
      delete process.env.CHAIN_ID;
      try {
        expect(() => {
          new OnChainExecutorService(actionStore, {} as any, {} as any, gateway);
        }).toThrow('Missing required environment variable: CHAIN_ID');
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
    });

    it('should query live Safe contract state directly from Base Sepolia', async () => {
      const safeConfig = await service.getOnChainSafeConfig();

      expect(safeConfig.guardAddress.toLowerCase()).toBe(realGuardAddress.toLowerCase());
      expect(safeConfig.owner.toLowerCase()).toBe(service.relayerWallet.address.toLowerCase());
      expect(safeConfig.nonce).toBeGreaterThanOrEqual(0n);
    });
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

  describe('Actual On-Chain Autonomous Execution & Settlement', () => {
    it('should broadcast and mine real Safe transaction on Base Sepolia and verify on-chain receipt', async () => {
      const action = actionStore.createAction({
        target: realSafeAddress,
        value: '0',
        data: '0x',
        token: realSafeAddress,
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '40000000',
        agentAddress: '0x1111111111111111111111111111111111111111',
        justification: 'Real on-chain autonomous test payment to vendor',
      });

      const result = await service.executeAutonomousPayment(action);

      // Verify on-chain execution result
      expect(result.status).toBe(TreasuryActionStatus.EXECUTED);
      expect(result.txHash).toMatch(/^0x[a-fA-F0-9]{64}$/);
      expect(result.receipt.status).toBe(1);

      // Verify action was persisted as EXECUTED with real txHash
      const stored = actionStore.getAction(action.id);
      expect(stored?.status).toBe(TreasuryActionStatus.EXECUTED);
      expect(stored?.txHash).toBe(result.txHash);

      // Verify event was emitted
      expect(mockServer.emit).toHaveBeenCalledWith(
        'action:executed',
        expect.objectContaining({
          action: expect.objectContaining({ id: action.id, status: 'EXECUTED' }),
          txHash: result.txHash,
        }),
      );

      // Verify the broadcasted tx using verifyTransaction against Base Sepolia provider
      const verification = await service.verifyTransaction(result.txHash);
      expect(verification.verified).toBe(true);
      expect(verification.receipt?.status).toBe(1);
    });
  });
});
