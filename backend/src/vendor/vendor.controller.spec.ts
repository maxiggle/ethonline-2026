import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, HttpException, HttpStatus, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { VendorController } from './vendor.controller';
import { DiscoveryController } from './discovery.controller';
import { VendorService } from './vendor.service';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { DatabaseModule } from '../database/database.module';
import { DatabaseService } from '../database/database.service';
import { randomBytes } from 'crypto';
import { ActionsController } from '../actions/actions.controller';
import { AgentsService } from '../agents/agents.service';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { X402_CONFIG } from '../x402/x402.constants';
import { loadX402Config } from '../x402/x402.config';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { Response } from 'express';

describe('VendorController (x402 Protocol & Company Bills)', () => {
  let controller: VendorController;
  let vendorService: VendorService;
  let onChainExecutor: { verifyTokenTransfer: jest.Mock };
  let databaseService: DatabaseService;

  const agentAddress = '0x1111111111111111111111111111111111111111';
  const ownerRequest = {
    user: { id: 'did:privy:agent_owner', walletAddress: agentAddress },
  } as unknown as AuthenticatedRequest;

  const agentsService = { assertAgentOwnership: jest.fn() };

  const allowDecision = (actionOverrides: Record<string, any> = {}) => ({
    action: {
      id: 'act_test_123',
      status: 'APPROVED',
      txHash: '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343',
      ...actionOverrides,
    },
    decision: {
      actionId: 'act_test_123',
      decision: GuardianDecisionType.ALLOW,
      riskScore: 10,
      reasons: ['Transaction complies with all deterministic mandate constraints.'],
      requiresHumanApproval: false,
    },
  });

  const mockActionsController = {
    proposeAction: jest.fn().mockImplementation(() => Promise.resolve(allowDecision())),
  };

  const buildUnpaidBill = () => ({
    id: 'bill_test_01',
    provider: 'google_cloud' as const,
    serviceName: 'Google Cloud Vertex AI',
    accountId: 'billingAccounts/01A2B3',
    organization: 'Acme Global',
    invoiceNumber: 'INV-TEST-8812',
    amount: '40000000',
    amountUsdc: 40,
    description: 'H100 Cluster Compute',
    paymentIdentifier: 'test_inv_8812',
    status: 'UNPAID_402' as const,
    dueDate: '2026-09-30T00:00:00.000Z',
    paymentRequirements: {
      address: vendorService.vendorAddress,
      amount: '40000000',
      token: vendorService.tokenAddress,
      chainId: vendorService.chainId,
    },
  });

  const verifiedTransfer = (amount = 40_000_000n) => ({
    verified: true as const,
    transferredAmount: amount,
  });

  beforeEach(async () => {
    process.env.RPC_URL = 'https://sepolia.base.org';
    process.env.SAFE_ADDRESS = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
    process.env.GUARD_ADDRESS = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
    process.env.CHAIN_ID = '84532';

    mockActionsController.proposeAction.mockClear();
    mockActionsController.proposeAction.mockImplementation(() => Promise.resolve(allowDecision()));
    agentsService.assertAgentOwnership.mockReset();
    agentsService.assertAgentOwnership.mockResolvedValue(undefined);

    const mockOnChainExecutor = { verifyTokenTransfer: jest.fn().mockResolvedValue(verifiedTransfer()) };

    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule],
      controllers: [VendorController, DiscoveryController],
      providers: [
        VendorService,
        { provide: OnChainExecutorService, useValue: mockOnChainExecutor },
        { provide: ActionsController, useValue: mockActionsController },
        { provide: AgentsService, useValue: agentsService },
        { provide: X402_CONFIG, useFactory: loadX402Config },
      ],
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<VendorController>(VendorController);
    vendorService = module.get<VendorService>(VendorService);
    onChainExecutor = module.get(OnChainExecutorService);
    databaseService = module.get(DatabaseService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('Route protection', () => {
    it('should require Privy auth on account, billing and invocation routes', () => {
      const protectedHandlers = [
        VendorController.prototype.getConnectedAccounts,
        VendorController.prototype.connectAccount,
        VendorController.prototype.disconnectAccount,
        VendorController.prototype.getBills,
        VendorController.prototype.payBill,
        VendorController.prototype.invokeService,
        DiscoveryController.prototype.callService,
      ];

      for (const handler of protectedHandlers) {
        expect(Reflect.getMetadata(GUARDS_METADATA, handler)).toContain(PrivyAuthGuard);
      }
    });

    it('should keep x402 resource challenges and catalog discovery public', () => {
      const publicHandlers = [
        VendorController.prototype.getBill,
        VendorController.prototype.getComputeResource,
        VendorController.prototype.getWeather,
        DiscoveryController.prototype.listResources,
        DiscoveryController.prototype.searchResources,
      ];

      for (const handler of publicHandlers) {
        expect(Reflect.getMetadata(GUARDS_METADATA, handler)).toBeUndefined();
      }
    });
  });

  describe('Connected Accounts', () => {
    it('should return empty connected accounts initially', () => {
      const accounts = controller.getConnectedAccounts();
      expect(accounts).toEqual([]);
    });

    it('should connect a new corporate account', () => {
      const newAcc = controller.connectAccount({
        provider: 'openai',
        name: 'OpenAI Enterprise Team',
        organization: 'Acme Global Enterprises Inc.',
        accountId: 'org-acme-prod-2026',
      });
      expect(newAcc.accountId).toBe('org-acme-prod-2026');
      expect(newAcc.status).toBe('CONNECTED');
      expect(controller.getConnectedAccounts().length).toBe(1);
    });
  });

  describe('Company Bills & x402 Challenge', () => {
    it('should return empty list of company bills initially', () => {
      const bills = controller.getBills();
      expect(bills).toEqual([]);
    });

    it('should throw HTTP 402 with X-Payment-Identifier when bill is unpaid', async () => {
      vendorService.addBill(buildUnpaidBill());

      const mockRes = { setHeader: jest.fn() } as unknown as Response;

      try {
        await controller.getBill('bill_test_01', undefined, mockRes);
        fail('Should have thrown HttpException');
      } catch (err) {
        expect(err).toBeInstanceOf(HttpException);
        expect((err as HttpException).getStatus()).toBe(HttpStatus.PAYMENT_REQUIRED);

        expect(mockRes.setHeader).toHaveBeenCalledWith(
          'X-Payment-Address',
          vendorService.vendorAddress,
        );
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-Amount', '40000000');
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-Identifier', 'test_inv_8812');
      }
    });

    it('should dispatch agent to pay bill and settle via x402', async () => {
      vendorService.addBill(buildUnpaidBill());

      const result = await controller.payBill(ownerRequest, 'bill_test_01', { agentAddress });

      expect(agentsService.assertAgentOwnership).toHaveBeenCalledWith(
        'did:privy:agent_owner',
        agentAddress,
      );
      expect(mockActionsController.proposeAction).toHaveBeenCalled();
      expect(onChainExecutor.verifyTokenTransfer).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({ minimumAmount: 40_000_000n }),
      );
      expect(result.bill.status).toBe('SETTLED_200');
      expect(result.bill.txHash).toBeDefined();
      expect(result.settlementError).toBeUndefined();
    });

    it('should refuse to pay a bill with an agent the caller does not own', async () => {
      vendorService.addBill(buildUnpaidBill());
      agentsService.assertAgentOwnership.mockRejectedValue(new ForbiddenException());

      await expect(
        controller.payBill(ownerRequest, 'bill_test_01', { agentAddress }),
      ).rejects.toThrow(ForbiddenException);

      expect(mockActionsController.proposeAction).not.toHaveBeenCalled();
      expect(vendorService.getBillById('bill_test_01')?.status).toBe('UNPAID_402');
    });

    it('should leave the bill UNPAID_402 when payment verification fails', async () => {
      vendorService.addBill(buildUnpaidBill());
      onChainExecutor.verifyTokenTransfer.mockResolvedValue({
        verified: false,
        error: 'Underpayment',
      });

      const result = await controller.payBill(ownerRequest, 'bill_test_01', { agentAddress });

      expect(result.bill.status).toBe('UNPAID_402');
      expect(result.settlementError).toBeDefined();
    });

    it('should settle only the bill that was paid, not another unpaid bill', async () => {
      const billA = buildUnpaidBill();
      const billB = { ...buildUnpaidBill(), id: 'bill_test_02', invoiceNumber: 'INV-TEST-8813' };
      vendorService.addBill(billA);
      vendorService.addBill(billB);

      await controller.payBill(ownerRequest, 'bill_test_02', { agentAddress });

      expect(vendorService.getBillById('bill_test_02')?.status).toBe('SETTLED_200');
      expect(vendorService.getBillById('bill_test_01')?.status).toBe('UNPAID_402');
    });
  });

  describe('HTTP 402 Payment Required Challenge (Compute)', () => {
    it('should throw HTTP 402 with required payment headers when X-Payment-TxHash is missing', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;

      try {
        await controller.getComputeResource(undefined, mockRes);
        fail('Should have thrown HttpException');
      } catch (err) {
        expect(err).toBeInstanceOf(HttpException);
        expect((err as HttpException).getStatus()).toBe(HttpStatus.PAYMENT_REQUIRED);

        expect(mockRes.setHeader).toHaveBeenCalledWith(
          'X-Payment-Address',
          vendorService.vendorAddress,
        );
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-Amount', '40000000');
        expect(mockRes.setHeader).toHaveBeenCalledWith(
          'X-Payment-Token',
          '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        );
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-ChainId', '84532');
      }
    });
  });

  describe('HTTP 200 OK Payment Verification & Access Grant (Compute)', () => {
    it('should unlock compute only after on-chain verification, called with the compute requirements', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;
      const realTxHash = '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343';

      const response = await controller.getComputeResource(realTxHash, mockRes);

      expect(onChainExecutor.verifyTokenTransfer).toHaveBeenCalledWith(
        realTxHash,
        expect.objectContaining({
          recipient: vendorService.vendorAddress,
          minimumAmount: 40_000_000n,
        }),
      );
      expect(response.status).toBe('UNLOCKED');
      expect(response.resource).toBe('compute:dedicated-cluster:h100-gpu-node-01');
      expect(response.txHash).toBe(realTxHash);
      expect(response.sessionToken).toBeDefined();
      expect(response.details.allocatedVramGb).toBe(80);
    });

    it('should reject a replayed hash and verify only once', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;
      const txHash = '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343';

      await controller.getComputeResource(txHash, mockRes);
      await expect(controller.getComputeResource(txHash, mockRes)).rejects.toThrow(
        BadRequestException,
      );

      expect(onChainExecutor.verifyTokenTransfer).toHaveBeenCalledTimes(1);
    });

    it('should record the verified transferred amount on the receipt, not the required amount', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;
      const txHash = `0x${randomBytes(32).toString('hex')}`;
      onChainExecutor.verifyTokenTransfer.mockResolvedValue(verifiedTransfer(45_000_000n));

      await controller.getComputeResource(txHash, mockRes);

      const receipt = databaseService.getOneSync<{ amount: string }>(
        'SELECT * FROM x402_payment_receipts WHERE tx_hash = ?',
        [txHash],
      );
      expect(receipt?.amount).toBe('45000000');
    });

    it('should reject a malformed hash without calling verification', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;

      await expect(controller.getComputeResource('not-a-hash', mockRes)).rejects.toThrow(
        BadRequestException,
      );
      expect(onChainExecutor.verifyTokenTransfer).not.toHaveBeenCalled();
    });

    it('should reject an unverified payment', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;
      onChainExecutor.verifyTokenTransfer.mockResolvedValue({
        verified: false,
        error: 'No matching Transfer log',
      });

      await expect(
        controller.getComputeResource(
          '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343',
          mockRes,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should not let a hash redeemed for compute also unlock weather', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;
      const txHash = '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343';

      await controller.getComputeResource(txHash, mockRes);

      await expect(controller.getWeather('San Francisco', txHash, mockRes)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('Bazaar Discovery & Search (x402 v2 catalog)', () => {
    it('should find the weather oracle when searching for "weather APIs"', () => {
      const results = vendorService.searchBazaar('weather APIs', 'http');
      expect(results.length).toBeGreaterThanOrEqual(1);
      expect(results[0].extensions.bazaar.info.serviceName).toContain('Open-Meteo');
      expect(results[0].resource).toContain('/x402/weather');
    });

    it('should filter by query tokens case-insensitively', () => {
      const results = vendorService.searchBazaar('BASE SEPOLIA chain');
      expect(results.length).toBeGreaterThanOrEqual(1);
      expect(results.some((r) => r.extensions.bazaar.info.tags.includes('base-sepolia'))).toBe(
        true,
      );
    });

    it('should list only the three x402 v2 resources, not the legacy vendor catalog', () => {
      const catalog = vendorService.getBazaarCatalog();
      expect(catalog).toHaveLength(3);
      expect(catalog.map((r) => r.resource)).toEqual([
        expect.stringContaining('/x402/weather'),
        expect.stringContaining('/x402/chain-report'),
        expect.stringContaining('/x402/partner-feed'),
      ]);
    });
  });

  describe('Weather Oracle x402 Endpoint', () => {
    it('should require a city query parameter', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;

      await expect(controller.getWeather(undefined, undefined, mockRes)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw HTTP 402 when payment header is missing', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;

      try {
        await controller.getWeather('San Francisco', undefined, mockRes);
        fail('Should have thrown HttpException 402');
      } catch (err) {
        expect(err).toBeInstanceOf(HttpException);
        expect((err as HttpException).getStatus()).toBe(HttpStatus.PAYMENT_REQUIRED);
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-Amount', '1000000');
        expect(mockRes.setHeader).toHaveBeenCalledWith(
          'X-Payment-Identifier',
          'weather_oracle_inv_004',
        );
      }
    });

    it('should return live weather telemetry when payment txHash is verified', async () => {
      const mockRes = { setHeader: jest.fn() } as unknown as Response;
      onChainExecutor.verifyTokenTransfer.mockResolvedValue(verifiedTransfer(1_000_000n));
      const txHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

      const data = await controller.getWeather('San Francisco', txHash, mockRes);
      expect(data.city).toContain('San Francisco');
      expect(data.temperatureC).toBeDefined();
      expect(data.conditions).toBeDefined();
      expect(data.settlementTx).toBe(txHash);
    });
  });

  describe('Service Invocation (invokeService, legacy Guardian-driven rail)', () => {
    // The x402 v2 catalog resources (/x402/*) are settled through the real @x402/express
    // middleware and the X402-002 Guardian-gated payments API, not this legacy path. It still
    // matches them in the catalog (so PENDING_SETTLEMENT/BLOCKED short-circuit correctly before
    // any settlement is attempted), but has no settlement handler wired for them yet.
    it('should 404 when a matched x402 v2 resource has no legacy settlement handler', async () => {
      onChainExecutor.verifyTokenTransfer.mockResolvedValue(verifiedTransfer(10_000n));

      await expect(
        controller.invokeService(ownerRequest, {
          resourceUrl: 'https://chapter2-backend.onrender.com/x402/weather',
          method: 'GET',
          params: { city: 'San Francisco' },
          agentAddress,
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('should return PENDING_SETTLEMENT and skip verification when no txHash exists yet', async () => {
      mockActionsController.proposeAction.mockResolvedValue(
        allowDecision({ txHash: undefined }),
      );

      const result = await controller.invokeService(ownerRequest, {
        resourceUrl: 'https://chapter2-backend.onrender.com/x402/weather',
        method: 'GET',
        params: { city: 'San Francisco' },
        agentAddress,
      });

      expect(result.status).toBe('PENDING_SETTLEMENT');
      expect(onChainExecutor.verifyTokenTransfer).not.toHaveBeenCalled();
    });

    it('should return BLOCKED when the guardian decision blocks the action', async () => {
      mockActionsController.proposeAction.mockResolvedValue({
        action: { id: 'act_blocked', status: 'REJECTED' },
        decision: {
          actionId: 'act_blocked',
          decision: GuardianDecisionType.BLOCK,
          riskScore: 100,
          reasons: ['Recipient is not on the approved whitelist.'],
          requiresHumanApproval: false,
        },
      });

      const result = await controller.invokeService(ownerRequest, {
        resourceUrl: 'https://chapter2-backend.onrender.com/x402/chain-report',
        method: 'GET',
        agentAddress,
      });

      expect(result.status).toBe('BLOCKED');
      expect(result.reason).toBe('Recipient is not on the approved whitelist.');
    });

    it('should reject an unknown resource without proposing a payment', async () => {
      await expect(
        controller.invokeService(ownerRequest, {
          resourceUrl: 'https://chapter2-backend.onrender.com/vendor/does-not-exist',
          method: 'GET',
          agentAddress,
        }),
      ).rejects.toThrow(NotFoundException);

      expect(mockActionsController.proposeAction).not.toHaveBeenCalled();
    });
  });
});
