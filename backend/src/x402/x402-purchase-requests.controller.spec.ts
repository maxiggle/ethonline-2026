import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Response } from 'express';
import { X402PurchaseRequestsController } from './x402-purchase-requests.controller';
import { X402PurchaseRequestsService } from './x402-purchase-requests.service';
import { ActionStoreService } from '../actions/action-store.service';
import { AgentsService } from '../agents/agents.service';
import { VendorService } from '../vendor/vendor.service';
import { DatabaseModule } from '../database/database.module';
import { AgentSignatureGuard } from './guards/agent-signature.guard';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AgentEntity } from '../agents/interfaces/agent.interface';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { AuthenticatedAgentRequest } from './interfaces/authenticated-agent-request.interface';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';

describe('X402PurchaseRequestsController', () => {
  let controller: X402PurchaseRequestsController;
  let actionStore: ActionStoreService;
  let agentsService: { assertAgentOwnership: jest.Mock };
  let vendorService: { getBazaarCatalog: jest.Mock };

  const OWNER_USER_ID = 'did:privy:owner';
  const OTHER_USER_ID = 'did:privy:other';
  const AGENT_ADDRESS = '0x1111111111111111111111111111111111111111';
  const RESOURCE_URL = 'https://chapter2-backend.onrender.com/x402/weather';

  const agent: AgentEntity = {
    id: 'agent_1',
    userId: OWNER_USER_ID,
    agentAddress: AGENT_ADDRESS,
    name: 'Test Agent',
    purpose: 'testing',
    safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
    guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
    chainId: 84532,
    status: 'ACTIVE',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const catalog = [
    {
      resource: RESOURCE_URL,
      type: 'http',
      x402Version: 2,
      lastUpdated: new Date().toISOString(),
      accepts: [
        {
          network: 'eip155:84532',
          asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
          amount: '10000',
          payTo: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
          scheme: 'exact',
        },
      ],
      extensions: {
        bazaar: {
          info: {
            serviceName: 'Open-Meteo Weather Oracle',
            description: 'Real-time weather telemetry',
            tags: ['weather'],
            input: { type: 'http', method: 'GET', queryParams: { city: 'Lagos' } },
            output: { type: 'json', example: {} },
          },
        },
      },
    },
  ];

  const buildAppRequest = (userId: string): AuthenticatedRequest =>
    ({ user: { id: userId } }) as unknown as AuthenticatedRequest;

  const buildAgentRequest = (overrides: Partial<AgentEntity> = {}): AuthenticatedAgentRequest =>
    ({ agent: { ...agent, ...overrides } }) as unknown as AuthenticatedAgentRequest;

  const buildResponse = (): Response => ({ status: jest.fn() }) as unknown as Response;

  const createDto = (overrides: Partial<any> = {}) => ({
    agentAddress: AGENT_ADDRESS,
    resourceUrl: RESOURCE_URL,
    queryParams: { city: 'Lagos' },
    justification: 'Fetch the weather for the morning report.',
    ...overrides,
  });

  beforeEach(async () => {
    agentsService = { assertAgentOwnership: jest.fn().mockResolvedValue(undefined) };
    vendorService = { getBazaarCatalog: jest.fn().mockReturnValue(catalog) };

    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule],
      controllers: [X402PurchaseRequestsController],
      providers: [
        X402PurchaseRequestsService,
        ActionStoreService,
        { provide: AgentsService, useValue: agentsService },
        { provide: VendorService, useValue: vendorService },
      ],
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(AgentSignatureGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get(X402PurchaseRequestsController);
    actionStore = module.get(ActionStoreService);
    actionStore.clear();
  });

  describe('create', () => {
    it('creates a QUEUED request with the catalog serviceName and amount', async () => {
      const created = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());

      expect(created.status).toBe('QUEUED');
      expect(created.serviceName).toBe('Open-Meteo Weather Oracle');
      expect(created.amount).toBe('10000');
      expect(created.agentAddress).toBe(AGENT_ADDRESS);
      expect(agentsService.assertAgentOwnership).toHaveBeenCalledWith(OWNER_USER_ID, AGENT_ADDRESS);
    });

    it('rejects an unknown resource', async () => {
      await expect(
        controller.create(buildAppRequest(OWNER_USER_ID), createDto({ resourceUrl: 'https://example.com/unknown' })),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects an unknown query parameter key', async () => {
      await expect(
        controller.create(buildAppRequest(OWNER_USER_ID), createDto({ queryParams: { country: 'Nigeria' } })),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a justification over 280 characters', async () => {
      await expect(
        controller.create(buildAppRequest(OWNER_USER_ID), createDto({ justification: 'x'.repeat(281) })),
      ).rejects.toThrow(BadRequestException);
    });

    it('propagates ownership failures as 403', async () => {
      agentsService.assertAgentOwnership.mockRejectedValueOnce(new ForbiddenException('not your agent'));

      await expect(controller.create(buildAppRequest(OTHER_USER_ID), createDto())).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('ownership on reads', () => {
    it('returns 404 for another user reading someone else’s request', async () => {
      const created = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());

      await expect(controller.getOne(buildAppRequest(OTHER_USER_ID), created.id)).rejects.toThrow(NotFoundException);
    });

    it('lists only the caller’s own requests', async () => {
      await controller.create(buildAppRequest(OWNER_USER_ID), createDto());

      const otherUsersList = await controller.list(buildAppRequest(OTHER_USER_ID));
      expect(otherUsersList).toEqual([]);

      const ownersList = await controller.list(buildAppRequest(OWNER_USER_ID));
      expect(ownersList).toHaveLength(1);
    });
  });

  describe('claim', () => {
    it('claims the oldest QUEUED request for the agent and returns 200', async () => {
      const created = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());
      const response = buildResponse();

      const claimed = await controller.claim(buildAgentRequest(), response);

      expect(claimed?.id).toBe(created.id);
      expect(claimed?.status).toBe('PROCESSING');
      expect(response.status).toHaveBeenCalledWith(200);
    });

    it('claims requests oldest first', async () => {
      const first = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());
      const second = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());

      const firstClaim = await controller.claim(buildAgentRequest(), buildResponse());
      expect(firstClaim?.id).toBe(first.id);

      const secondClaim = await controller.claim(buildAgentRequest(), buildResponse());
      expect(secondClaim?.id).toBe(second.id);
    });

    it('returns 204 when there is nothing to claim', async () => {
      const response = buildResponse();

      const claimed = await controller.claim(buildAgentRequest(), response);

      expect(claimed).toBeUndefined();
      expect(response.status).toHaveBeenCalledWith(204);
    });
  });

  describe('progress', () => {
    async function claimedRequest() {
      const created = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());
      await controller.claim(buildAgentRequest(), buildResponse());
      return created;
    }

    it('rejects progress from an agent that did not claim the request', async () => {
      const created = await claimedRequest();
      const otherAgent = '0x9999999999999999999999999999999999999999';

      await expect(
        controller.reportProgress(buildAgentRequest({ agentAddress: otherAgent }), created.id, {
          actionId: 'act_missing',
          decision: 'ALLOW' as any,
          reasons: [],
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a foreign actionId', async () => {
      const created = await claimedRequest();
      const foreignAction = actionStore.createAction({
        target: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        value: '0',
        data: '0x',
        token: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        recipient: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
        amount: '10000',
        agentAddress: '0x9999999999999999999999999999999999999999',
        justification: `x402: ${RESOURCE_URL} | someone else's agent`,
      });

      await expect(
        controller.reportProgress(buildAgentRequest(), created.id, {
          actionId: foreignAction.id,
          decision: 'ALLOW' as any,
          reasons: [],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects an actionId whose justification does not authorize this resource', async () => {
      const created = await claimedRequest();
      const mismatchedAction = actionStore.createAction({
        target: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        value: '0',
        data: '0x',
        token: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        recipient: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
        amount: '10000',
        agentAddress: AGENT_ADDRESS,
        justification: `x402: https://chapter2-backend.onrender.com/x402/chain-report | wrong resource`,
      });

      await expect(
        controller.reportProgress(buildAgentRequest(), created.id, {
          actionId: mismatchedAction.id,
          decision: 'ALLOW' as any,
          reasons: [],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('sets AUTHORIZED with the actionId, decision and reasons', async () => {
      const created = await claimedRequest();
      const action = actionStore.createAction({
        target: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        value: '0',
        data: '0x',
        token: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        recipient: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
        amount: '10000',
        agentAddress: AGENT_ADDRESS,
        justification: `x402: ${RESOURCE_URL}?city=Lagos | Fetch the weather`,
      });

      const authorized = await controller.reportProgress(buildAgentRequest(), created.id, {
        actionId: action.id,
        decision: 'ALLOW' as any,
        reasons: ['within limit'],
      });

      expect(authorized.status).toBe('AUTHORIZED');
      expect(authorized.actionId).toBe(action.id);
      expect(authorized.decision).toBe('ALLOW');
      expect(authorized.reasons).toEqual(['within limit']);
    });
  });

  describe('result', () => {
    async function authorizedRequest() {
      const created = await controller.create(buildAppRequest(OWNER_USER_ID), createDto());
      await controller.claim(buildAgentRequest(), buildResponse());
      const action = actionStore.createAction({
        target: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        value: '0',
        data: '0x',
        token: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        recipient: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
        amount: '10000',
        agentAddress: AGENT_ADDRESS,
        justification: `x402: ${RESOURCE_URL}?city=Lagos | Fetch the weather`,
      });
      await controller.reportProgress(buildAgentRequest(), created.id, {
        actionId: action.id,
        decision: 'ALLOW' as any,
        reasons: [],
      });
      return { created, action };
    }

    it('accepts PAID only once the action is EXECUTED with a matching hash', async () => {
      const { created, action } = await authorizedRequest();
      const txHash = `0x${'ab'.repeat(32)}`;

      await expect(
        controller.reportResult(buildAgentRequest(), created.id, {
          status: 'PAID' as any,
          actionId: action.id,
          transactionHash: txHash,
        }),
      ).rejects.toThrow(BadRequestException);

      actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash });

      const paid = await controller.reportResult(buildAgentRequest(), created.id, {
        status: 'PAID' as any,
        actionId: action.id,
        transactionHash: txHash,
        response: { temperatureC: 22 },
      });

      expect(paid.status).toBe('PAID');
      expect(paid.transactionHash).toBe(txHash.toLowerCase());
      expect(paid.response).toEqual({ temperatureC: 22 });
    });

    it('rejects PAID when the transaction hash does not match the EXECUTED action', async () => {
      const { created, action } = await authorizedRequest();
      actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash: `0x${'ab'.repeat(32)}` });

      await expect(
        controller.reportResult(buildAgentRequest(), created.id, {
          status: 'PAID' as any,
          actionId: action.id,
          transactionHash: `0x${'cd'.repeat(32)}`,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('requires decision BLOCK for a BLOCKED result', async () => {
      const { created } = await authorizedRequest();

      await expect(
        controller.reportResult(buildAgentRequest(), created.id, {
          status: 'BLOCKED' as any,
          decision: 'ALLOW' as any,
          reasons: ['not approved'],
        }),
      ).rejects.toThrow(BadRequestException);

      const blocked = await controller.reportResult(buildAgentRequest(), created.id, {
        status: 'BLOCKED' as any,
        decision: 'BLOCK' as any,
        reasons: ['not approved'],
      });
      expect(blocked.status).toBe('BLOCKED');
    });

    it('rejects a response payload over 32 KB', async () => {
      const { created, action } = await authorizedRequest();
      const txHash = `0x${'ab'.repeat(32)}`;
      actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash });

      await expect(
        controller.reportResult(buildAgentRequest(), created.id, {
          status: 'PAID' as any,
          actionId: action.id,
          transactionHash: txHash,
          response: { blob: 'x'.repeat(33 * 1024) },
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('returns 409 once a terminal state has been reported', async () => {
      const { created, action } = await authorizedRequest();
      const txHash = `0x${'ab'.repeat(32)}`;
      actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash });

      await controller.reportResult(buildAgentRequest(), created.id, {
        status: 'PAID' as any,
        actionId: action.id,
        transactionHash: txHash,
      });

      await expect(
        controller.reportResult(buildAgentRequest(), created.id, {
          status: 'FAILED' as any,
          error: 'retry',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });
});
