import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { Wallet } from 'ethers';
import { X402PaymentsController } from './x402-payments.controller';
import { X402PaymentsService } from './x402-payments.service';
import { X402SpendingPolicyService } from './x402-spending-policy.service';
import { ActionStoreService } from '../actions/action-store.service';
import { EventsGateway } from '../gateway/events.gateway';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { DatabaseModule } from '../database/database.module';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { X402_CONFIG } from './x402.constants';
import { X402Config } from './x402.config';
import { AgentSignatureGuard } from './guards/agent-signature.guard';
import { AgentEntity } from '../agents/interfaces/agent.interface';
import { AuthenticatedAgentRequest } from './interfaces/authenticated-agent-request.interface';
import { Server } from 'socket.io';

describe('X402PaymentsController', () => {
  let controller: X402PaymentsController;
  let actionStore: ActionStoreService;
  let eventsGateway: EventsGateway;
  let spendingPolicy: { evaluate: jest.Mock };
  let onChainExecutor: {
    verifyTokenTransfer: jest.Mock;
    executeAutonomousPayment: jest.Mock;
    executeEscalatedPayment: jest.Mock;
  };

  const config: X402Config = {
    network: 'eip155:84532',
    facilitatorUrl: 'https://x402.org/facilitator',
    usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    payToAddress: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
    partnerPayToAddress: '0xbB55f3472773EAB736E5BCaC5FE6e6C5B30f5E35',
    publicBaseUrl: 'https://chapter2-backend.onrender.com',
    approvedPayTo: ['0x4087a2be5527867612424fF2b0B821318D4Dc2fa'],
    autonomousLimit: 1_000_000n,
    dailyLimit: 5_000_000n,
    ledgerApproverAddress: '',
  };

  const agent: AgentEntity = {
    id: 'agent_1',
    userId: 'did:privy:owner',
    agentAddress: '0x1111111111111111111111111111111111111111',
    name: 'Test Agent',
    purpose: 'testing',
    safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
    guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
    chainId: 84532,
    status: 'ACTIVE',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  let approverWallet: Wallet;

  const buildRequest = (overrides: Partial<AgentEntity> = {}): AuthenticatedAgentRequest =>
    ({ agent: { ...agent, ...overrides } }) as unknown as AuthenticatedAgentRequest;

  const authorizeDto = (overrides: Partial<any> = {}) => ({
    resourceUrl: 'https://chapter2-backend.onrender.com/x402/chain-report',
    paymentRequirements: {
      scheme: 'exact',
      network: config.network,
      asset: config.usdcAddress,
      amount: '500000',
      payTo: config.payToAddress,
    },
    justification: 'buy a chain report',
    ...overrides,
  });

  const buildEscalationTypedData = (overrides: Partial<any> = {}, message: Partial<any> = {}) => ({
    domain: {
      name: 'USDC',
      version: '2',
      chainId: 84532,
      verifyingContract: config.usdcAddress,
    },
    types: {
      TransferWithAuthorization: [
        { name: 'from', type: 'address' },
        { name: 'to', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'validAfter', type: 'uint256' },
        { name: 'validBefore', type: 'uint256' },
        { name: 'nonce', type: 'bytes32' },
      ],
    },
    primaryType: 'TransferWithAuthorization',
    message: {
      from: approverWallet.address,
      to: config.payToAddress,
      value: '2000000',
      validAfter: 0,
      validBefore: Math.floor(Date.now() / 1000) + 3600,
      nonce: `0x${'00'.repeat(32)}`,
      ...message,
    },
    ...overrides,
  });

  beforeEach(async () => {
    process.env.SAFE_ADDRESS = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
    process.env.GUARD_ADDRESS = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
    process.env.CHAIN_ID = '84532';

    approverWallet = Wallet.createRandom() as unknown as Wallet;
    config.ledgerApproverAddress = approverWallet.address;

    spendingPolicy = { evaluate: jest.fn() };
    onChainExecutor = {
      verifyTokenTransfer: jest.fn(),
      executeAutonomousPayment: jest.fn(),
      executeEscalatedPayment: jest.fn(),
    };

    const mockServer = { emit: jest.fn() } as unknown as Server;

    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule],
      controllers: [X402PaymentsController],
      providers: [
        X402PaymentsService,
        ActionStoreService,
        EventsGateway,
        { provide: X402SpendingPolicyService, useValue: spendingPolicy },
        { provide: OnChainExecutorService, useValue: onChainExecutor },
        { provide: X402_CONFIG, useValue: config },
      ],
    })
      .overrideGuard(AgentSignatureGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get(X402PaymentsController);
    actionStore = module.get(ActionStoreService);
    eventsGateway = module.get(EventsGateway);
    eventsGateway.server = mockServer;
    actionStore.clear();
  });

  describe('authorize', () => {
    it('ALLOWs and never touches the relayer', async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ALLOW,
        riskScore: 10,
        reasons: ['Payment complies with the x402 spending policy.'],
      });

      const result = await controller.authorize(buildRequest(), authorizeDto());

      expect(result.decision).toBe(GuardianDecisionType.ALLOW);
      const action = actionStore.getAction(result.actionId);
      expect(action?.status).toBe(TreasuryActionStatus.APPROVED);
      expect(onChainExecutor.executeAutonomousPayment).not.toHaveBeenCalled();
      expect(onChainExecutor.executeEscalatedPayment).not.toHaveBeenCalled();
    });

    it('ESCALATEs and leaves the action PENDING without touching the relayer', async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ESCALATE,
        riskScore: 60,
        reasons: ['Amount exceeds the autonomous limit.'],
      });

      const result = await controller.authorize(buildRequest(), authorizeDto());

      expect(result.decision).toBe(GuardianDecisionType.ESCALATE);
      const action = actionStore.getAction(result.actionId);
      expect(action?.status).toBe(TreasuryActionStatus.PENDING);
      expect(onChainExecutor.executeAutonomousPayment).not.toHaveBeenCalled();
      expect(onChainExecutor.executeEscalatedPayment).not.toHaveBeenCalled();
    });

    it('BLOCKs and rejects the action without touching the relayer', async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: ['Payee is not on the approved recipient list.'],
      });

      const result = await controller.authorize(buildRequest(), authorizeDto());

      expect(result.decision).toBe(GuardianDecisionType.BLOCK);
      const action = actionStore.getAction(result.actionId);
      expect(action?.status).toBe(TreasuryActionStatus.REJECTED);
      expect(onChainExecutor.executeAutonomousPayment).not.toHaveBeenCalled();
      expect(onChainExecutor.executeEscalatedPayment).not.toHaveBeenCalled();
    });
  });

  describe('escalation submission', () => {
    const escalateAction = async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ESCALATE,
        riskScore: 60,
        reasons: ['Amount exceeds the autonomous limit.'],
      });
      const result = await controller.authorize(
        buildRequest(),
        authorizeDto({ paymentRequirements: { ...authorizeDto().paymentRequirements, amount: '2000000' } }),
      );
      return result.actionId;
    };

    it('accepts valid typed data and stores AWAITING_SIGNATURE', async () => {
      const actionId = await escalateAction();
      const result = await controller.submitEscalation(buildRequest(), actionId, {
        typedData: buildEscalationTypedData(),
      });
      expect(result.status).toBe('AWAITING_SIGNATURE');
    });

    it('rejects a mismatched from address', async () => {
      const actionId = await escalateAction();
      await expect(
        controller.submitEscalation(buildRequest(), actionId, {
          typedData: buildEscalationTypedData({}, { from: '0x2222222222222222222222222222222222222222' }),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a mismatched to address', async () => {
      const actionId = await escalateAction();
      await expect(
        controller.submitEscalation(buildRequest(), actionId, {
          typedData: buildEscalationTypedData({}, { to: '0x3333333333333333333333333333333333333333' }),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a mismatched value', async () => {
      const actionId = await escalateAction();
      await expect(
        controller.submitEscalation(buildRequest(), actionId, {
          typedData: buildEscalationTypedData({}, { value: '1' }),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects the wrong verifying contract (token)', async () => {
      const actionId = await escalateAction();
      await expect(
        controller.submitEscalation(buildRequest(), actionId, {
          typedData: buildEscalationTypedData({
            domain: { ...buildEscalationTypedData().domain, verifyingContract: '0x0000000000000000000000000000000000000001' },
          }),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects the wrong chain id', async () => {
      const actionId = await escalateAction();
      await expect(
        controller.submitEscalation(buildRequest(), actionId, {
          typedData: buildEscalationTypedData({
            domain: { ...buildEscalationTypedData().domain, chainId: 8453 },
          }),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects an expired validBefore', async () => {
      const actionId = await escalateAction();
      await expect(
        controller.submitEscalation(buildRequest(), actionId, {
          typedData: buildEscalationTypedData({}, { validBefore: Math.floor(Date.now() / 1000) - 10 }),
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('approval signature', () => {
    const escalateAction = async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ESCALATE,
        riskScore: 60,
        reasons: ['Amount exceeds the autonomous limit.'],
      });
      const result = await controller.authorize(
        buildRequest(),
        authorizeDto({ paymentRequirements: { ...authorizeDto().paymentRequirements, amount: '2000000' } }),
      );
      await controller.submitEscalation(buildRequest(), result.actionId, {
        typedData: buildEscalationTypedData(),
      });
      return result.actionId;
    };

    it('accepts a signature from the configured Ledger approver', async () => {
      const actionId = await escalateAction();
      const typedData = buildEscalationTypedData();
      const signature = await approverWallet.signTypedData(
        typedData.domain,
        typedData.types,
        typedData.message,
      );

      const result = await controller.approve(actionId, { signature });
      expect(result.status).toBe('SIGNED');
      expect(actionStore.getAction(actionId)?.status).toBe(TreasuryActionStatus.APPROVED);
    });

    it('rejects a signature from a different wallet', async () => {
      const actionId = await escalateAction();
      const otherWallet = Wallet.createRandom() as unknown as Wallet;
      const typedData = buildEscalationTypedData();
      const signature = await otherWallet.signTypedData(typedData.domain, typedData.types, typedData.message);

      await expect(controller.approve(actionId, { signature })).rejects.toThrow(UnauthorizedException);
      expect(actionStore.getAction(actionId)?.status).toBe(TreasuryActionStatus.PENDING);
    });

    it('rejects a signature over a tampered message', async () => {
      const actionId = await escalateAction();
      const typedData = buildEscalationTypedData();
      const signature = await approverWallet.signTypedData(typedData.domain, typedData.types, {
        ...typedData.message,
        value: '999999',
      });

      await expect(controller.approve(actionId, { signature })).rejects.toThrow(UnauthorizedException);
    });

    it('refuses to approve once the payment authorization has expired', async () => {
      const actionId = await escalateAction();
      const typedData = buildEscalationTypedData();
      const signature = await approverWallet.signTypedData(
        typedData.domain,
        typedData.types,
        typedData.message,
      );
      const dateNow = jest.spyOn(Date, 'now').mockReturnValue((typedData.message.validBefore + 1) * 1000);

      try {
        await expect(controller.approve(actionId, { signature })).rejects.toThrow(BadRequestException);
      } finally {
        dateNow.mockRestore();
      }
      expect(actionStore.getAction(actionId)?.status).toBe(TreasuryActionStatus.PENDING);
    });
  });

  describe('reject', () => {
    const escalateAction = async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ESCALATE,
        riskScore: 60,
        reasons: ['Amount exceeds the autonomous limit.'],
      });
      const result = await controller.authorize(
        buildRequest(),
        authorizeDto({ paymentRequirements: { ...authorizeDto().paymentRequirements, amount: '2000000' } }),
      );
      await controller.submitEscalation(buildRequest(), result.actionId, {
        typedData: buildEscalationTypedData(),
      });
      return result.actionId;
    };

    it('accepts a valid rejection signature from the approver', async () => {
      const actionId = await escalateAction();
      const signature = await approverWallet.signMessage(`chapter2-reject:${actionId}`);

      const result = await controller.reject(actionId, { signature });
      expect(result.status).toBe('REJECTED');
      expect(actionStore.getAction(actionId)?.status).toBe(TreasuryActionStatus.REJECTED);
    });

    it('rejects a rejection signature from the wrong signer', async () => {
      const actionId = await escalateAction();
      const otherWallet = Wallet.createRandom() as unknown as Wallet;
      const signature = await otherWallet.signMessage(`chapter2-reject:${actionId}`);

      await expect(controller.reject(actionId, { signature })).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('settlement', () => {
    const allowAction = async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ALLOW,
        riskScore: 10,
        reasons: ['Payment complies with the x402 spending policy.'],
      });
      const result = await controller.authorize(buildRequest(), authorizeDto());
      return result.actionId;
    };

    it('marks the action EXECUTED when the transfer verifies', async () => {
      const actionId = await allowAction();
      onChainExecutor.verifyTokenTransfer.mockResolvedValue({ verified: true, transferredAmount: 500_000n });
      const txHash = `0x${'ab'.repeat(32)}`;

      const result = await controller.settle(buildRequest(), actionId, { transactionHash: txHash });

      expect(result.status).toBe('EXECUTED');
      expect(actionStore.getAction(actionId)?.status).toBe(TreasuryActionStatus.EXECUTED);
      expect(actionStore.getAction(actionId)?.txHash).toBe(txHash);
    });

    it('leaves the action APPROVED when verification fails', async () => {
      const actionId = await allowAction();
      onChainExecutor.verifyTokenTransfer.mockResolvedValue({
        verified: false,
        error: 'No matching Transfer log',
      });
      const txHash = `0x${'cd'.repeat(32)}`;

      await expect(
        controller.settle(buildRequest(), actionId, { transactionHash: txHash }),
      ).rejects.toThrow(BadRequestException);
      expect(actionStore.getAction(actionId)?.status).toBe(TreasuryActionStatus.APPROVED);
    });

    it('refuses settlement of an action that is not APPROVED', async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: ['Payee is not on the approved recipient list.'],
      });
      const authResult = await controller.authorize(buildRequest(), authorizeDto());

      await expect(
        controller.settle(buildRequest(), authResult.actionId, { transactionHash: `0x${'ef'.repeat(32)}` }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('ownership', () => {
    it('refuses to return payment status for an action owned by another agent', async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ALLOW,
        riskScore: 10,
        reasons: ['Payment complies with the x402 spending policy.'],
      });
      const result = await controller.authorize(buildRequest(), authorizeDto());

      await expect(
        controller.getPayment(
          buildRequest({ agentAddress: '0x9999999999999999999999999999999999999999' }),
          result.actionId,
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('404s for an unknown action', async () => {
      await expect(controller.getPayment(buildRequest(), 'act_does_not_exist')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('approvals listing', () => {
    it('lists pending escalations for the console', async () => {
      spendingPolicy.evaluate.mockReturnValue({
        decision: GuardianDecisionType.ESCALATE,
        riskScore: 60,
        reasons: ['Amount exceeds the autonomous limit.'],
      });
      const result = await controller.authorize(
        buildRequest(),
        authorizeDto({ paymentRequirements: { ...authorizeDto().paymentRequirements, amount: '2000000' } }),
      );
      await controller.submitEscalation(buildRequest(), result.actionId, {
        typedData: buildEscalationTypedData(),
      });

      const pending = await controller.getPendingApprovals();
      const entry = pending.find((p) => p.actionId === result.actionId);
      expect(entry?.reasons).toEqual(['Amount exceeds the autonomous limit.']);
    });

    it('returns the approver config', () => {
      const result = controller.getApprovalConfig();
      expect(result.approverAddress).toBe(config.ledgerApproverAddress);
      expect(result.network).toBe(config.network);
    });
  });
});
