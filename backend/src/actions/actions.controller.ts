import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Query,
  BadRequestException,
  NotFoundException,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { getAddress, keccak256, toUtf8Bytes } from 'ethers';
import { ActionStoreService } from './action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { BalanceReservationService } from '../reservations/balance-reservation.service';
import { RiskAnalysisService } from '../guardian/risk-analysis.service';
import { Eip712Service } from '../crypto/eip712.service';
import { LedgerKeyRingService } from '../ledger/ledger-keyring.service';
import { WorldSelfieService } from '../world/world-selfie.service';
import { EventsGateway } from '../gateway/events.gateway';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { SubmitApprovalDto } from '../domain/dto/submit-approval.dto';
import { ActionResponseDto } from '../domain/dto/action-response.dto';
import { RejectActionDto } from './dto/reject-action.dto';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecision, GuardianDecisionType } from '../domain/guardian-decision.entity';
import { TreasuryMandate } from '../domain/treasury-mandate.entity';
import { TreasuryActionApprovalParams } from '../crypto/interfaces/eip712.interface';
import { LedgerClearSignPrompt } from '../ledger/interfaces/ledger-keyring.interface';

@Controller('actions')
export class ActionsController {
  constructor(
    private readonly actionStore: ActionStoreService,
    private readonly policyEngine: PolicyEngineService,
    private readonly balanceReservation: BalanceReservationService,
    private readonly riskAnalysis: RiskAnalysisService,
    private readonly eip712Service: Eip712Service,
    private readonly ledgerService: LedgerKeyRingService,
    private readonly worldSelfieService: WorldSelfieService,
    private readonly eventsGateway: EventsGateway,
  ) {}

  private computeMandateHash(mandate: TreasuryMandate): string {
    return keccak256(
      toUtf8Bytes(`CHAPTER2_MANDATE_${mandate.chainId}_${mandate.safeAddress}_${mandate.guardAddress}`),
    );
  }

  @Post('propose')
  @HttpCode(HttpStatus.CREATED)
  async proposeAction(@Body() dto: ProposeActionDto): Promise<ActionResponseDto> {
    if (dto.worldIdProof) {
      const selfieResult = await this.worldSelfieService.verifySelfieProof(
        dto.worldIdProof as any,
        dto.agentAddress,
      );
      if (!selfieResult.success) {
        throw new BadRequestException(`World ID proof verification failed: ${selfieResult.error}`);
      }
    }

    const action = this.actionStore.createAction(dto);

    const reservationResult = this.balanceReservation.acquireReservation(
      action.id,
      action.amount,
    );

    if (!reservationResult.success) {
      this.actionStore.updateStatus(action.id, TreasuryActionStatus.REJECTED);
      const blockedDecision: GuardianDecision = {
        actionId: action.id,
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: [reservationResult.reason || 'Insufficient daily reservation budget'],
        deterministicPassed: false,
        requiresHumanApproval: false,
        evaluatedAt: new Date(),
      };

      this.eventsGateway.emitActionBlocked({ action, decision: blockedDecision });
      return { action, decision: blockedDecision };
    }

    this.eventsGateway.emitActionProposed(action);

    const decision = await this.riskAnalysis.evaluateAction(action);
    action.riskScore = decision.riskScore;
    action.requiresHumanApproval = decision.requiresHumanApproval;

    if (decision.decision === GuardianDecisionType.BLOCK) {
      this.balanceReservation.releaseReservation(action.id);
      this.actionStore.updateStatus(action.id, TreasuryActionStatus.REJECTED);
      this.eventsGateway.emitActionBlocked({ action, decision });
      return { action, decision };
    }

    if (decision.decision === GuardianDecisionType.ESCALATE) {
      this.actionStore.updateStatus(action.id, TreasuryActionStatus.PENDING);

      const mandate = this.policyEngine.getMandate();
      const approvalParams: TreasuryActionApprovalParams = {
        actionId: action.id,
        agent: action.agentAddress,
        recipient: action.recipient,
        token: action.token,
        amount: action.amount,
        nonce: action.nonce,
        deadline: action.deadline,
        mandateHash: this.computeMandateHash(mandate),
        riskScore: action.riskScore,
      };

      const typedData = this.eip712Service.generateTypedData(approvalParams);
      const prompt = this.ledgerService.formatClearSignPrompt(approvalParams);

      this.eventsGateway.emitActionEscalated({
        action,
        decision,
        typedData,
        prompt,
      });

      return { action, decision, typedData };
    }

    this.balanceReservation.commitReservation(action.id);
    this.actionStore.updateStatus(action.id, TreasuryActionStatus.APPROVED);
    this.eventsGateway.emitActionApproved({ action });

    return { action, decision };
  }

  @Get()
  listActions(@Query('status') status?: TreasuryActionStatus): TreasuryAction[] {
    return this.actionStore.listActions(status);
  }

  @Get('pending')
  getPendingActions(): TreasuryAction[] {
    return this.actionStore.getPendingActions();
  }

  @Get(':id')
  getAction(@Param('id') id: string): TreasuryAction {
    const action = this.actionStore.getAction(id);
    if (!action) {
      throw new NotFoundException(`Action ${id} not found`);
    }
    return action;
  }

  @Get(':id/clear-sign')
  getClearSignPrompt(@Param('id') id: string): LedgerClearSignPrompt {
    const action = this.actionStore.getAction(id);
    if (!action) {
      throw new NotFoundException(`Action ${id} not found`);
    }

    const mandate = this.policyEngine.getMandate();
    const approvalParams: TreasuryActionApprovalParams = {
      actionId: action.id,
      agent: action.agentAddress,
      recipient: action.recipient,
      token: action.token,
      amount: action.amount,
      nonce: action.nonce,
      deadline: action.deadline,
      mandateHash: this.computeMandateHash(mandate),
      riskScore: action.riskScore,
    };

    return this.ledgerService.formatClearSignPrompt(approvalParams);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  async approveAction(
    @Param('id') id: string,
    @Body() dto: SubmitApprovalDto,
  ): Promise<{
    action: TreasuryAction;
    encodedPayload: string;
    signer: string;
  }> {
    const action = this.actionStore.getAction(id);
    if (!action) {
      throw new NotFoundException(`Action ${id} not found`);
    }

    if (action.status !== TreasuryActionStatus.PENDING) {
      throw new BadRequestException(`Action ${id} is not in PENDING state (Current status: ${action.status})`);
    }

    const mandate = this.policyEngine.getMandate();
    const approvalParams: TreasuryActionApprovalParams = {
      actionId: action.id,
      agent: action.agentAddress,
      recipient: action.recipient,
      token: action.token,
      amount: action.amount,
      nonce: action.nonce,
      deadline: action.deadline,
      mandateHash: this.computeMandateHash(mandate),
      riskScore: action.riskScore,
    };

    const normalizedSigner = getAddress(dto.signer);

    const isSignatureValid = this.eip712Service.verifySignature(
      approvalParams,
      dto.signature,
      normalizedSigner,
    );
    if (!isSignatureValid) {
      throw new BadRequestException('Invalid EIP-712 approval signature');
    }

    const hardwareSigner = await this.ledgerService.getSignerAddress();
    const isHardwareSigner = normalizedSigner.toLowerCase() === hardwareSigner.toLowerCase();
    const isWorldIdVerified = await this.worldSelfieService.isHumanSignerVerified(normalizedSigner);

    if (!isHardwareSigner && !isWorldIdVerified) {
      throw new BadRequestException(
        `Signer ${dto.signer} is not an authorized hardware signer or verified World ID operator.`,
      );
    }

    if (isWorldIdVerified) {
      await this.worldSelfieService.touchActivity(normalizedSigner);
    }

    const encodedPayload = this.eip712Service.encodeEscalatedPayload(
      approvalParams,
      dto.signature,
    );

    this.balanceReservation.commitReservation(action.id);
    this.actionStore.updateStatus(action.id, TreasuryActionStatus.APPROVED, {
      signature: dto.signature,
    });

    this.eventsGateway.emitActionApproved({
      action,
      executionPayload: { approval: approvalParams, signature: dto.signature },
      safeTxData: encodedPayload,
    });

    return {
      action,
      encodedPayload,
      signer: normalizedSigner,
    };
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  rejectAction(
    @Param('id') id: string,
    @Body() dto?: RejectActionDto,
  ): {
    action: TreasuryAction;
    rejected: boolean;
    reason?: string;
  } {
    const action = this.actionStore.getAction(id);
    if (!action) {
      throw new NotFoundException(`Action ${id} not found`);
    }

    if (action.status !== TreasuryActionStatus.PENDING) {
      throw new BadRequestException(`Action ${id} is not in PENDING state (Current status: ${action.status})`);
    }

    this.balanceReservation.releaseReservation(action.id);
    this.actionStore.updateStatus(action.id, TreasuryActionStatus.REJECTED);

    const reason = dto?.reason || 'Rejected by human operator';
    this.eventsGateway.emitActionRejected({ action, reason });

    return {
      action,
      rejected: true,
      reason,
    };
  }
}
