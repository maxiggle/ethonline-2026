import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ActionsController } from './actions.controller';
import { ActionStoreService } from './action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { BalanceReservationService } from '../reservations/balance-reservation.service';
import { RiskAnalysisService } from '../guardian/risk-analysis.service';
import { Eip712Service } from '../crypto/eip712.service';
import { LedgerKeyRingService } from '../ledger/ledger-keyring.service';
import { WorldSelfieService } from '../world/world-selfie.service';
import { EventsGateway } from '../gateway/events.gateway';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { Server } from 'socket.io';

describe('ActionsController', () => {
  let controller: ActionsController;
  let actionStore: ActionStoreService;
  let ledgerService: LedgerKeyRingService;
  let worldSelfieService: WorldSelfieService;
  let gateway: EventsGateway;
  let mockServer: Partial<Server>;

  const validRecipient = '0x0000000000000000000000000000000000041c4e';
  const invalidRecipient = '0x9999999999999999999999999999999999999999';
  const validToken = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
  const agentAddress = '0x1111111111111111111111111111111111111111';

  beforeEach(async () => {
    mockServer = {
      emit: jest.fn(),
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
      ],
    }).compile();

    controller = module.get<ActionsController>(ActionsController);
    actionStore = module.get<ActionStoreService>(ActionStoreService);
    ledgerService = module.get<LedgerKeyRingService>(LedgerKeyRingService);
    worldSelfieService = module.get<WorldSelfieService>(WorldSelfieService);
    gateway = module.get<EventsGateway>(EventsGateway);
    gateway.server = mockServer as Server;
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
    it('should approve escalated action with valid hardware signature and encode Safe payload', async () => {
      const proposed = await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '200000000', // $200 (ESCALATE)
        agentAddress,
        justification: 'Major database server cluster upgrade',
      });

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
      const proposed = await controller.proposeAction({
        target: validToken,
        value: '0',
        data: '0x',
        token: validToken,
        recipient: validRecipient,
        amount: '200000000',
        agentAddress,
        justification: 'Tamper test',
      });

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
});
