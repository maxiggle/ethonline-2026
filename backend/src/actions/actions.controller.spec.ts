import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { HDNodeWallet, Wallet } from 'ethers';
import { ActionsController } from './actions.controller';
import { ActionStoreService } from './action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { BalanceReservationService } from '../reservations/balance-reservation.service';
import { RiskAnalysisService } from '../guardian/risk-analysis.service';
import { Eip712Service } from '../crypto/eip712.service';
import { LedgerKeyRingService } from '../ledger/ledger-keyring.service';
import { WorldSelfieService } from '../world/world-selfie.service';
import { DEFAULT_WORLD_ACTION } from '../world/world.constants';
import { EventsGateway } from '../gateway/events.gateway';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { Server } from 'socket.io';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { AgentsService } from '../agents/agents.service';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';

describe('ActionsController', () => {
  let controller: ActionsController;
  let ledgerService: LedgerKeyRingService;
  let worldSelfieService: WorldSelfieService;
  let eip712Service: Eip712Service;
  let gateway: EventsGateway;
  let mockServer: Partial<Server>;
  let onChainExecutor: {
    getGuardHumanSigner: jest.Mock;
  };

  const validRecipient = '0x0000000000000000000000000000000000041c4e';
  const invalidRecipient = '0x9999999999999999999999999999999999999999';
  const validToken = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
  const agentAddress = '0x1111111111111111111111111111111111111111';
  const agentsService = { assertAgentOwnership: jest.fn() };

  const buildEscalatedProposal = (justification: string): ProposeActionDto => ({
    target: validToken,
    value: '0',
    data: '0x',
    token: validToken,
    recipient: validRecipient,
    amount: '200000000', // $200 (ESCALATE)
    agentAddress,
    justification,
  });

  const signApprovalWith = async (wallet: HDNodeWallet, actionId: string): Promise<string> => {
    const typedData = eip712Service.generateTypedData(
      controller.getClearSignPrompt(actionId).rawApproval,
    );
    return wallet.signTypedData(typedData.domain, typedData.types, typedData.message);
  };

  beforeEach(async () => {
    mockServer = {
      emit: jest.fn(),
    };
    agentsService.assertAgentOwnership.mockReset();
    onChainExecutor = {
      getGuardHumanSigner: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ActionsController],
      providers: [
        ActionStoreService,
        PolicyEngineService,
        BalanceReservationService,
        RiskAnalysisService,
        Eip712Service,
        LedgerKeyRingService,
        WorldSelfieService,
        EventsGateway,
        { provide: AgentsService, useValue: agentsService },
        { provide: OnChainExecutorService, useValue: onChainExecutor },
      ],
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<ActionsController>(ActionsController);
    ledgerService = module.get<LedgerKeyRingService>(LedgerKeyRingService);
    worldSelfieService = module.get<WorldSelfieService>(WorldSelfieService);
    eip712Service = module.get<Eip712Service>(Eip712Service);
    gateway = module.get<EventsGateway>(EventsGateway);
    gateway.server = mockServer as Server;

    onChainExecutor.getGuardHumanSigner.mockResolvedValue(await ledgerService.getSignerAddress());
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('proposeAction', () => {
    it('should process a benign small payment within limit as ALLOW', async () => {
      const dto: ProposeActionDto = {
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '50000000', // $50 (under $100 cap)
        agentAddress,
        justification: 'Automated weekly RPC infrastructure payment',
      };

      const result = await controller.proposeAction(dto);

      expect(result.action.status).toBe(TreasuryActionStatus.APPROVED);
      expect(result.decision.decision).toBe(GuardianDecisionType.ALLOW);
      expect(result.decision.requiresHumanApproval).toBe(false);
      expect(mockServer.emit).toHaveBeenCalledWith(
        'action:approved',
        expect.anything(),
      );
    });

    it('should process an action exceeding single cap as ESCALATE with typed data', async () => {
      const dto: ProposeActionDto = {
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '250000000', // $250 (exceeds $100 cap)
        agentAddress,
        justification: 'Critical annual compute node expansion',
      };

      const result = await controller.proposeAction(dto);

      expect(result.action.status).toBe(TreasuryActionStatus.PENDING);
      expect(result.decision.decision).toBe(GuardianDecisionType.ESCALATE);
      expect(result.decision.requiresHumanApproval).toBe(true);
      expect(result.typedData).toBeDefined();
      expect(result.typedData?.primaryType).toBe('TreasuryActionApproval');
      expect(mockServer.emit).toHaveBeenCalledWith(
        'action:escalated',
        expect.anything(),
      );
    });

    it('should process an unapproved recipient as BLOCK and release reservation', async () => {
      const dto: ProposeActionDto = {
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: invalidRecipient,
        amount: '10000000',
        agentAddress,
        justification: 'Suspicious external transfer',
      };

      const result = await controller.proposeAction(dto);

      expect(result.action.status).toBe(TreasuryActionStatus.REJECTED);
      expect(result.decision.decision).toBe(GuardianDecisionType.BLOCK);
      expect(mockServer.emit).toHaveBeenCalledWith(
        'action:blocked',
        expect.anything(),
      );
    });

    it('should block and reject proposal if daily reservation budget is exceeded', async () => {
      // Mandate daily limit is 500,000,000 ($500)
      const dto: ProposeActionDto = {
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '600000000', // $600 exceeds $500 daily limit
        agentAddress,
        justification: 'Huge daily withdrawal',
      };

      const result = await controller.proposeAction(dto);

      expect(result.action.status).toBe(TreasuryActionStatus.REJECTED);
      expect(result.decision.decision).toBe(GuardianDecisionType.BLOCK);
      expect(result.decision.reasons[0]).toContain('Insufficient remaining daily budget');
    });
  });

  describe('listing & queries', () => {
    it('should list all actions and filter by status', async () => {
      await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '20000000',
        agentAddress,
        justification: 'Benign small payment',
      });

      await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '150000000',
        agentAddress,
        justification: 'Escalated payment',
      });

      const all = controller.listActions();
      expect(all.length).toBe(2);

      const pending = controller.getPendingActions();
      expect(pending.length).toBe(1);
      expect(pending[0].amount).toBe('150000000');
    });

    it('should retrieve single action by ID or throw NotFoundException', async () => {
      const res = await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '10000000',
        agentAddress,
        justification: 'Check get',
      });

      const found = controller.getAction(res.action.id);
      expect(found.id).toBe(res.action.id);

      expect(() => controller.getAction('non-existent')).toThrow(NotFoundException);
    });

    it('should format clear-sign prompt for an action', async () => {
      const res = await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '150000000',
        agentAddress,
        justification: 'Needs hardware prompt',
      });

      const prompt = controller.getClearSignPrompt(res.action.id);
      expect(prompt.title).toBeDefined();
      expect(prompt.fields.length).toBeGreaterThan(0);
    });
  });

  describe('approveAction & rejectAction', () => {
    it('should approve an escalated action signed by the Guard humanSigner and dispatch execution', async () => {
      const proposed = await controller.proposeAction(
        buildEscalatedProposal('Major database server cluster upgrade'),
      );

      expect(proposed.action.status).toBe(TreasuryActionStatus.PENDING);

      const prompt = controller.getClearSignPrompt(proposed.action.id);
      const signResult = await ledgerService.signApproval(prompt.rawApproval);

      const approvalRes = await controller.approveAction(proposed.action.id, {
        actionId: proposed.action.id,
        signature: signResult.signature,
        signer: signResult.signer,
      });

      expect(approvalRes.action.status).toBe(TreasuryActionStatus.APPROVED);
      expect(approvalRes.encodedPayload).toMatch(/^0x/);
      expect(mockServer.emit).toHaveBeenCalledWith(
        'action:approved',
        expect.anything(),
      );
    });

    it('should reject approval with invalid signature', async () => {
      const proposed = await controller.proposeAction(buildEscalatedProposal('Tamper test'));

      const invalidSig =
        '0x111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111b';

      await expect(
        controller.approveAction(proposed.action.id, {
          actionId: proposed.action.id,
          signature: invalidSig,
          signer: await ledgerService.getSignerAddress(),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject approval if action is not in PENDING state', async () => {
      const proposed = await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '10000000', // Benign -> ALLOW -> APPROVED immediately
        agentAddress,
        justification: 'Already approved',
      });

      await expect(
        controller.approveAction(proposed.action.id, {
          actionId: proposed.action.id,
          signature: '0x1234',
          signer: await ledgerService.getSignerAddress(),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should refuse approvals validly signed by a wallet that is not the Guard humanSigner', async () => {
      const proposed = await controller.proposeAction(buildEscalatedProposal('Outsider signer'));
      const outsiderWallet = Wallet.createRandom();
      const signature = await signApprovalWith(outsiderWallet, proposed.action.id);

      await expect(
        controller.approveAction(proposed.action.id, {
          actionId: proposed.action.id,
          signature,
          signer: outsiderWallet.address,
        }),
      ).rejects.toThrow(ForbiddenException);

      expect(controller.getAction(proposed.action.id).status).toBe(TreasuryActionStatus.PENDING);
    });

    it('should refuse approvals from a World ID verified operator who is not the Guard humanSigner', async () => {
      const operatorWallet = Wallet.createRandom();
      await worldSelfieService.bindHumanSigner(operatorWallet.address, {
        protocol_version: '4.0',
        merkle_root: '0x1f38b1492b4a78c187e148e6efddb55018659174be88390cb3347f89b9087c53',
        nullifier_hash: '0x2506e0f80bc43f146522c0e9b980c6575791eb0023a1a3641bfec91436154676',
        proof: '0xproofbytes_world_id_operator',
        credential_type: 11,
        action: DEFAULT_WORLD_ACTION,
        signal: operatorWallet.address,
      });
      expect(await worldSelfieService.isHumanSignerVerified(operatorWallet.address)).toBe(true);

      const proposed = await controller.proposeAction(buildEscalatedProposal('World ID operator'));
      const signature = await signApprovalWith(operatorWallet, proposed.action.id);

      await expect(
        controller.approveAction(proposed.action.id, {
          actionId: proposed.action.id,
          signature,
          signer: operatorWallet.address,
        }),
      ).rejects.toThrow(ForbiddenException);

      expect(controller.getAction(proposed.action.id).status).toBe(TreasuryActionStatus.PENDING);
    });

    it('should fail closed when the Guard humanSigner cannot be read on-chain', async () => {
      onChainExecutor.getGuardHumanSigner.mockRejectedValue(new Error('RPC unavailable'));
      const proposed = await controller.proposeAction(buildEscalatedProposal('RPC outage'));
      const signResult = await ledgerService.signApproval(
        controller.getClearSignPrompt(proposed.action.id).rawApproval,
      );

      await expect(
        controller.approveAction(proposed.action.id, {
          actionId: proposed.action.id,
          signature: signResult.signature,
          signer: signResult.signer,
        }),
      ).rejects.toThrow('RPC unavailable');

      expect(controller.getAction(proposed.action.id).status).toBe(TreasuryActionStatus.PENDING);
    });

    it('should reject an escalated action and release reservation', async () => {
      const proposed = await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '300000000',
        agentAddress,
        justification: 'Will be rejected',
      });

      const rejectRes = controller.rejectAction(proposed.action.id, {
        reason: 'Operator deemed cost unnecessary',
      });

      expect(rejectRes.rejected).toBe(true);
      expect(rejectRes.action.status).toBe(TreasuryActionStatus.REJECTED);
      expect(mockServer.emit).toHaveBeenCalledWith(
        'action:rejected',
        expect.anything(),
      );
    });
  });

  describe('authenticated routes', () => {
    const request = {
      user: { id: 'did:privy:treasury_owner', walletAddress: agentAddress },
    } as unknown as AuthenticatedRequest;

    it('should require the Privy auth guard on every actions route', () => {
      const guards = Reflect.getMetadata(GUARDS_METADATA, ActionsController);
      expect(guards).toContain(PrivyAuthGuard);
    });

    it('should propose on behalf of an agent owned by the authenticated user', async () => {
      agentsService.assertAgentOwnership.mockResolvedValue(undefined);

      const result = await controller.proposeActionForUser(request, {
        ...buildEscalatedProposal('Owned agent payment'),
        amount: '50000000',
      });

      expect(agentsService.assertAgentOwnership).toHaveBeenCalledWith(
        'did:privy:treasury_owner',
        agentAddress,
      );
      expect(result.decision.decision).toBe(GuardianDecisionType.ALLOW);
    });

    it('should refuse proposals for agents the user does not own', async () => {
      agentsService.assertAgentOwnership.mockRejectedValue(new ForbiddenException());

      await expect(
        controller.proposeActionForUser(request, buildEscalatedProposal('Unowned agent')),
      ).rejects.toThrow(ForbiddenException);
      expect(controller.listActions()).toHaveLength(0);
    });

    it('should refuse approving or rejecting actions of agents the user does not own', async () => {
      const proposed = await controller.proposeAction(buildEscalatedProposal('Unowned approval'));
      agentsService.assertAgentOwnership.mockRejectedValue(new ForbiddenException());

      const prompt = controller.getClearSignPrompt(proposed.action.id);
      const signResult = await ledgerService.signApproval(prompt.rawApproval);

      await expect(
        controller.approveActionForUser(request, proposed.action.id, {
          actionId: proposed.action.id,
          signature: signResult.signature,
          signer: signResult.signer,
        }),
      ).rejects.toThrow(ForbiddenException);
      await expect(
        controller.rejectActionForUser(request, proposed.action.id, { reason: 'Not my agent' }),
      ).rejects.toThrow(ForbiddenException);
      expect(controller.getAction(proposed.action.id).status).toBe(TreasuryActionStatus.PENDING);
    });
  });
});
