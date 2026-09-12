import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, HttpException, HttpStatus } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { VendorController } from './vendor.controller';
import { DiscoveryController } from './discovery.controller';
import { VendorService } from './vendor.service';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { ActionStoreService } from '../actions/action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { Eip712Service } from '../crypto/eip712.service';
import { EventsGateway } from '../gateway/events.gateway';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { ActionsController } from '../actions/actions.controller';
import { AgentsService } from '../agents/agents.service';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { Response } from 'express';

describe('VendorController (x402 Protocol & Company Bills)', () => {
  let controller: VendorController;
  let vendorService: VendorService;
  let actionStore: ActionStoreService;
  let onChainExecutor: OnChainExecutorService;

  const agentAddress = '0x1111111111111111111111111111111111111111';
  const ownerRequest = {
    user: { id: 'did:privy:agent_owner', walletAddress: agentAddress },
  } as unknown as AuthenticatedRequest;

  const agentsService = { assertAgentOwnership: jest.fn() };

  const mockActionsController = {
    proposeAction: jest.fn().mockImplementation((dto) => {
      return Promise.resolve({
        action: {
          id: 'act_test_123',
          ...dto,
          status: TreasuryActionStatus.APPROVED,
          txHash: '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343',
        },
        decision: {
          actionId: 'act_test_123',
          decision: 'ALLOW',
          riskScore: 10,
          requiresHumanApproval: false,
        },
      });
    }),
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

  beforeEach(async () => {
    process.env.RPC_URL = 'https://sepolia.base.org';
    process.env.SAFE_ADDRESS = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
    process.env.GUARD_ADDRESS = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
    process.env.CHAIN_ID = '84532';

    mockActionsController.proposeAction.mockClear();
    agentsService.assertAgentOwnership.mockReset();
    agentsService.assertAgentOwnership.mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      controllers: [VendorController],
      providers: [
        VendorService,
        OnChainExecutorService,
        ActionStoreService,
        PolicyEngineService,
        Eip712Service,
        EventsGateway,
        {
          provide: ActionsController,
          useValue: mockActionsController,
        },
        { provide: AgentsService, useValue: agentsService },
      ],
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<VendorController>(VendorController);
    vendorService = module.get<VendorService>(VendorService);
    actionStore = module.get<ActionStoreService>(ActionStoreService);
    onChainExecutor = module.get<OnChainExecutorService>(OnChainExecutorService);
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

      const headersMap: Record<string, string> = {};
      const mockRes = {
        setHeader: jest.fn((key: string, val: string) => {
          headersMap[key] = val;
        }),
      } as unknown as Response;

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
      expect(result.bill.status).toBe('SETTLED_200');
      expect(result.bill.txHash).toBeDefined();
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
  });

  describe('HTTP 402 Payment Required Challenge (Compute)', () => {
    it('should throw HTTP 402 with required payment headers when X-Payment-TxHash is missing', async () => {
      const headersMap: Record<string, string> = {};
      const mockRes = {
        setHeader: jest.fn((key: string, val: string) => {
          headersMap[key] = val;
        }),
      } as unknown as Response;

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
    it('should unlock compute resource when valid payment action exists in action store', async () => {
      const mockRes = {
        setHeader: jest.fn(),
      } as unknown as Response;

      const realTxHash = '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343';
      const action = actionStore.createAction({
        target: process.env.SAFE_ADDRESS!,
        value: '0',
        data: '0x',
        token: process.env.SAFE_ADDRESS!,
        recipient: vendorService.vendorAddress,
        amount: '40000000',
        agentAddress,
        justification: 'x402 compute payment',
      });
      actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash: realTxHash });

      const response = await controller.getComputeResource(realTxHash, mockRes);

      expect(response.status).toBe('UNLOCKED');
      expect(response.resource).toBe('compute:dedicated-cluster:h100-gpu-node-01');
      expect(response.txHash).toBe(realTxHash);
      expect(response.sessionToken).toBeDefined();
      expect(response.details.allocatedVramGb).toBe(80);
    });
  });

  describe('Bazaar Discovery & Search', () => {
    it('should find weather services when searching for "weather APIs"', () => {
      const results = vendorService.searchBazaar('weather APIs', 'http');
      expect(results.length).toBeGreaterThanOrEqual(1);
      expect(results[0].extensions.bazaar.info.serviceName).toContain('AccuWeather');
      expect(results[0].resource).toContain('/vendor/weather');
    });

    it('should filter by query tokens case-insensitively', () => {
      const results = vendorService.searchBazaar('GPU compute');
      expect(results.length).toBeGreaterThanOrEqual(1);
      expect(results.some((r) => r.extensions.bazaar.info.tags.includes('gpu'))).toBe(true);
    });
  });

  describe('Weather Oracle x402 Endpoint', () => {
    it('should throw HTTP 402 when payment header is missing', async () => {
      const mockRes = {
        setHeader: jest.fn(),
      } as unknown as Response;

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

    it('should return live weather telemetry when payment txHash is provided', async () => {
      const mockRes = {
        setHeader: jest.fn(),
      } as unknown as Response;
      const txHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

      const data = await controller.getWeather('San Francisco', txHash, mockRes);
      expect(data.city).toContain('San Francisco');
      expect(data.temperatureC).toBeDefined();
      expect(data.conditions).toBeDefined();
      expect(data.settlementTx).toBe(txHash);
    });
  });

  describe('Service Invocation (invokeService)', () => {
    it('should autonomously settle and invoke weather service', async () => {
      const result = await controller.invokeService(ownerRequest, {
        resourceUrl: 'https://chapter2-backend.onrender.com/vendor/weather',
        method: 'GET',
        params: { city: 'San Francisco' },
        agentAddress,
      });

      expect(result.status).toBe('SUCCESS');
      expect(result.costUsdc).toBe(1);
      expect(result.txHash).toBeDefined();
      expect(result.data?.city).toContain('San Francisco');
    });
  });
});
