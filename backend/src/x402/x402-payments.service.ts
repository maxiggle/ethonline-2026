import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { getAddress, verifyMessage, verifyTypedData } from 'ethers';
import { ActionStoreService } from '../actions/action-store.service';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecision, GuardianDecisionType } from '../domain/guardian-decision.entity';
import { EventsGateway } from '../gateway/events.gateway';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { DatabaseService } from '../database/database.service';
import { X402EscalationRow } from '../database/database.interface';
import { AgentEntity } from '../agents/interfaces/agent.interface';
import { X402SpendingPolicyService } from './x402-spending-policy.service';
import { X402_CONFIG } from './x402.constants';
import { X402Config } from './x402.config';
import { AuthorizePaymentDto } from './dto/authorize-payment.dto';

const REJECT_MESSAGE_PREFIX = 'chapter2-reject:';

@Injectable()
export class X402PaymentsService {
  private readonly escalationReasons = new Map<string, string[]>();

  constructor(
    private readonly actionStore: ActionStoreService,
    private readonly spendingPolicy: X402SpendingPolicyService,
    private readonly onChainExecutor: OnChainExecutorService,
    private readonly databaseService: DatabaseService,
    private readonly eventsGateway: EventsGateway,
    @Inject(X402_CONFIG) private readonly config: X402Config,
  ) {}

  async authorize(
    agent: AgentEntity,
    dto: AuthorizePaymentDto,
  ): Promise<{ actionId: string; decision: GuardianDecisionType; riskScore: number; reasons: string[] }> {
    const { resourceUrl, paymentRequirements, justification } = dto;
    const fullJustification = `x402: ${resourceUrl} | ${justification}`;

    const action = this.actionStore.createAction({
      target: paymentRequirements.asset,
      value: '0',
      data: '0x',
      token: paymentRequirements.asset,
      recipient: paymentRequirements.payTo,
      amount: paymentRequirements.amount,
      agentAddress: agent.agentAddress,
      justification: fullJustification,
    });

    this.eventsGateway.emitActionProposed(action);

    const policy = this.spendingPolicy.evaluate(agent.agentAddress, paymentRequirements, fullJustification);
    action.riskScore = policy.riskScore;
    action.requiresHumanApproval = policy.decision !== GuardianDecisionType.ALLOW;

    if (policy.decision === GuardianDecisionType.BLOCK) {
      this.actionStore.updateStatus(action.id, TreasuryActionStatus.REJECTED);
      this.eventsGateway.emitActionBlocked({
        action,
        decision: this.toGuardianDecision(action, policy.decision, policy.reasons),
      });
    } else if (policy.decision === GuardianDecisionType.ESCALATE) {
      this.actionStore.updateStatus(action.id, TreasuryActionStatus.PENDING);
      this.escalationReasons.set(action.id, policy.reasons);
    } else {
      this.actionStore.updateStatus(action.id, TreasuryActionStatus.APPROVED);
      this.eventsGateway.emitActionApproved({ action });
    }

    return {
      actionId: action.id,
      decision: policy.decision,
      riskScore: policy.riskScore,
      reasons: policy.reasons,
    };
  }

  async submitEscalation(
    agent: AgentEntity,
    actionId: string,
    typedData: Record<string, any>,
  ): Promise<{ actionId: string; status: string }> {
    const action = this.getOwnedAction(agent, actionId);
    if (action.status !== TreasuryActionStatus.PENDING) {
      throw new BadRequestException(`Action ${actionId} is not awaiting escalation`);
    }

    this.assertValidEscalationTypedData(typedData, action);

    const reasons = this.escalationReasons.get(actionId);
    if (!reasons) {
      throw new BadRequestException(`No spending policy escalation recorded for action ${actionId}`);
    }

    const now = new Date().toISOString();
    await this.databaseService.run(
      `INSERT INTO x402_escalations (action_id, resource_url, typed_data, reasons, signature, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        actionId,
        this.extractResourceUrl(action),
        JSON.stringify(typedData),
        JSON.stringify(reasons),
        null,
        'AWAITING_SIGNATURE',
        now,
        now,
      ],
    );
    this.escalationReasons.delete(actionId);

    this.eventsGateway.emitActionEscalated({
      action,
      decision: this.toGuardianDecision(action, GuardianDecisionType.ESCALATE, reasons),
      typedData,
    });

    return { actionId, status: 'AWAITING_SIGNATURE' };
  }

  async getPaymentStatus(
    agent: AgentEntity,
    actionId: string,
  ): Promise<{
    actionId: string;
    decision: GuardianDecisionType;
    actionStatus: TreasuryActionStatus;
    escalationStatus?: string;
    signature?: string;
  }> {
    const action = this.getOwnedAction(agent, actionId);
    const escalation = await this.databaseService.getOne<X402EscalationRow>(
      'SELECT * FROM x402_escalations WHERE action_id = ?',
      [actionId],
    );

    return {
      actionId: action.id,
      decision: this.deriveDecision(action, escalation),
      actionStatus: action.status,
      escalationStatus: escalation?.status,
      signature: action.signature,
    };
  }

  async settle(
    agent: AgentEntity,
    actionId: string,
    transactionHash: string,
  ): Promise<{ actionId: string; status: 'EXECUTED'; transactionHash: string }> {
    const action = this.getOwnedAction(agent, actionId);
    if (action.status !== TreasuryActionStatus.APPROVED) {
      throw new BadRequestException(`Action ${actionId} must be APPROVED before settlement`);
    }

    const verifyResult = await this.onChainExecutor.verifyTokenTransfer(transactionHash, {
      token: action.token,
      recipient: action.recipient,
      minimumAmount: BigInt(action.amount),
    });
    if (verifyResult.verified === false) {
      throw new BadRequestException(`On-chain settlement verification failed: ${verifyResult.error}`);
    }

    const updated = this.actionStore.updateStatus(actionId, TreasuryActionStatus.EXECUTED, {
      txHash: transactionHash,
    });
    if (updated) {
      this.eventsGateway.emitActionExecuted({ action: updated, txHash: transactionHash });
    }

    return { actionId, status: 'EXECUTED', transactionHash: transactionHash.toLowerCase() };
  }

  getApprovalConfig(): { approverAddress: string; network: string; usdcAddress: string } {
    return {
      approverAddress: this.config.ledgerApproverAddress,
      network: this.config.network,
      usdcAddress: this.config.usdcAddress,
    };
  }

  async listPendingApprovals(): Promise<
    Array<{
      actionId: string;
      resourceUrl: string;
      amount: string;
      payTo: string;
      agentAddress: string;
      justification: string;
      riskScore: number;
      reasons: string[];
      typedData: Record<string, any>;
      createdAt: string;
    }>
  > {
    const rows = await this.databaseService.query<X402EscalationRow>('SELECT * FROM x402_escalations');
    const pending: Array<{
      actionId: string;
      resourceUrl: string;
      amount: string;
      payTo: string;
      agentAddress: string;
      justification: string;
      riskScore: number;
      reasons: string[];
      typedData: Record<string, any>;
      createdAt: string;
    }> = [];

    for (const row of rows) {
      if (row.status !== 'AWAITING_SIGNATURE') continue;
      const action = this.actionStore.getAction(row.action_id);
      if (!action) continue;
      pending.push({
        actionId: row.action_id,
        resourceUrl: row.resource_url,
        amount: action.amount,
        payTo: action.recipient,
        agentAddress: action.agentAddress,
        justification: action.justification,
        riskScore: action.riskScore,
        reasons: JSON.parse(row.reasons),
        typedData: JSON.parse(row.typed_data),
        createdAt: row.created_at,
      });
    }
    return pending;
  }

  async approveWithSignature(actionId: string, signature: string): Promise<{ actionId: string; status: string }> {
    const escalation = await this.getAwaitingEscalation(actionId);
    const typedData = JSON.parse(escalation.typed_data);
    if (Number(typedData.message?.validBefore) <= Math.floor(Date.now() / 1000)) {
      throw new BadRequestException(
        `The payment authorization for action ${actionId} has expired; the agent must request payment again`,
      );
    }
    const types = { ...(typedData.types || {}) };
    delete types.EIP712Domain;

    let recovered: string;
    try {
      recovered = verifyTypedData(typedData.domain, types, typedData.message, signature);
    } catch {
      throw new UnauthorizedException('Malformed approval signature');
    }
    if (!this.isSameAddress(recovered, this.config.ledgerApproverAddress)) {
      throw new UnauthorizedException(
        'Approval signature does not recover to the configured Ledger approver address',
      );
    }

    const now = new Date().toISOString();
    await this.databaseService.run(
      `UPDATE x402_escalations SET status = ?, signature = ?, updated_at = ? WHERE action_id = ?`,
      ['SIGNED', signature, now, actionId],
    );

    const action = this.actionStore.updateStatus(actionId, TreasuryActionStatus.APPROVED, { signature });
    if (action) {
      this.eventsGateway.emitActionApproved({ action });
    }

    return { actionId, status: 'SIGNED' };
  }

  async rejectWithSignature(actionId: string, signature: string): Promise<{ actionId: string; status: string }> {
    await this.getAwaitingEscalation(actionId);

    let recovered: string;
    try {
      recovered = verifyMessage(`${REJECT_MESSAGE_PREFIX}${actionId}`, signature);
    } catch {
      throw new UnauthorizedException('Malformed rejection signature');
    }
    if (!this.isSameAddress(recovered, this.config.ledgerApproverAddress)) {
      throw new UnauthorizedException(
        'Rejection signature does not recover to the configured Ledger approver address',
      );
    }

    const now = new Date().toISOString();
    await this.databaseService.run(
      `UPDATE x402_escalations SET status = ?, signature = ?, updated_at = ? WHERE action_id = ?`,
      ['REJECTED', signature, now, actionId],
    );

    const action = this.actionStore.updateStatus(actionId, TreasuryActionStatus.REJECTED);
    if (action) {
      this.eventsGateway.emitActionRejected({
        action,
        reason: 'Rejected by the human approver via a Ledger-signed message.',
      });
    }

    return { actionId, status: 'REJECTED' };
  }

  private async getAwaitingEscalation(actionId: string): Promise<X402EscalationRow> {
    const escalation = await this.databaseService.getOne<X402EscalationRow>(
      'SELECT * FROM x402_escalations WHERE action_id = ?',
      [actionId],
    );
    if (!escalation || escalation.status !== 'AWAITING_SIGNATURE') {
      throw new NotFoundException(`No escalation awaiting a signature for action ${actionId}`);
    }
    return escalation;
  }

  private getOwnedAction(agent: AgentEntity, actionId: string): TreasuryAction {
    const action = this.actionStore.getAction(actionId);
    if (!action) {
      throw new NotFoundException(`x402 payment action ${actionId} not found`);
    }
    if (action.agentAddress.toLowerCase() !== agent.agentAddress.toLowerCase()) {
      throw new ForbiddenException(`Action ${actionId} does not belong to agent ${agent.agentAddress}`);
    }
    return action;
  }

  private deriveDecision(
    action: TreasuryAction,
    escalation: X402EscalationRow | null,
  ): GuardianDecisionType {
    if (action.status === TreasuryActionStatus.APPROVED || action.status === TreasuryActionStatus.EXECUTED) {
      return GuardianDecisionType.ALLOW;
    }
    if (action.status === TreasuryActionStatus.PENDING) {
      return GuardianDecisionType.ESCALATE;
    }
    return escalation ? GuardianDecisionType.ESCALATE : GuardianDecisionType.BLOCK;
  }

  private toGuardianDecision(
    action: TreasuryAction,
    decision: GuardianDecisionType,
    reasons: string[],
  ): GuardianDecision {
    return {
      actionId: action.id,
      decision,
      riskScore: action.riskScore,
      reasons,
      deterministicPassed: decision === GuardianDecisionType.ALLOW,
      requiresHumanApproval: decision !== GuardianDecisionType.ALLOW,
      evaluatedAt: new Date(),
    };
  }

  private extractResourceUrl(action: TreasuryAction): string {
    const match = action.justification.match(/^x402: (.*?) \| /);
    return match ? match[1] : action.justification;
  }

  private isSameAddress(a: unknown, b: string): boolean {
    if (typeof a !== 'string') return false;
    try {
      return getAddress(a) === getAddress(b);
    } catch {
      return false;
    }
  }

  /**
   * Validates that the client-supplied EIP-3009 typed data authorizes exactly this action's
   * transfer, signed by the configured Ledger approver, before it is stored for the human to see.
   */
  private assertValidEscalationTypedData(typedData: any, action: TreasuryAction): void {
    if (!typedData || typeof typedData !== 'object') {
      throw new BadRequestException('typedData is required');
    }
    if (typedData.primaryType !== 'TransferWithAuthorization') {
      throw new BadRequestException("typedData.primaryType must be 'TransferWithAuthorization'");
    }

    const domain = typedData.domain || {};
    if (!this.isSameAddress(domain.verifyingContract, this.config.usdcAddress)) {
      throw new BadRequestException('typedData.domain.verifyingContract must be the configured USDC contract');
    }
    if (Number(domain.chainId) !== 84532) {
      throw new BadRequestException('typedData.domain.chainId must be 84532');
    }

    const message = typedData.message || {};
    if (!this.isSameAddress(message.from, this.config.ledgerApproverAddress)) {
      throw new BadRequestException('typedData.message.from must be the configured Ledger approver address');
    }
    if (!this.isSameAddress(message.to, action.recipient)) {
      throw new BadRequestException('typedData.message.to must match the action recipient');
    }
    if (String(message.value) !== String(action.amount)) {
      throw new BadRequestException('typedData.message.value must match the action amount');
    }

    const validBefore = Number(message.validBefore);
    if (!Number.isFinite(validBefore) || validBefore <= Math.floor(Date.now() / 1000)) {
      throw new BadRequestException('typedData.message.validBefore must be in the future');
    }
  }
}
