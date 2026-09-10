import { Injectable } from '@nestjs/common';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';

@Injectable()
export class ActionStoreService {
  private actions = new Map<string, TreasuryAction>();
  private currentNonce = 1;

  createAction(dto: ProposeActionDto, customId?: string): TreasuryAction {
    const id = customId || `act_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const now = new Date();
    const deadline = Math.floor(now.getTime() / 1000) + 3600;

    const action: TreasuryAction = {
      id,
      target: dto.target,
      value: dto.value || '0',
      data: dto.data || '0x',
      token: dto.token,
      recipient: dto.recipient,
      amount: dto.amount,
      agentAddress: dto.agentAddress,
      justification: dto.justification,
      status: TreasuryActionStatus.PENDING,
      nonce: this.currentNonce++,
      deadline,
      riskScore: 0,
      requiresHumanApproval: false,
      createdAt: now,
      updatedAt: now,
    };

    this.actions.set(id, action);
    return action;
  }

  getAction(id: string): TreasuryAction | undefined {
    return this.actions.get(id);
  }

  listActions(status?: TreasuryActionStatus): TreasuryAction[] {
    const all = Array.from(this.actions.values());
    if (!status) {
      return all;
    }
    return all.filter((action) => action.status === status);
  }

  getPendingActions(): TreasuryAction[] {
    return this.listActions(TreasuryActionStatus.PENDING);
  }

  updateStatus(
    id: string,
    status: TreasuryActionStatus,
    metadata?: { signature?: string; txHash?: string },
  ): TreasuryAction | undefined {
    const action = this.actions.get(id);
    if (!action) {
      return undefined;
    }

    action.status = status;
    action.updatedAt = new Date();

    if (metadata?.signature) {
      action.signature = metadata.signature;
    }
    if (metadata?.txHash) {
      action.txHash = metadata.txHash;
    }

    return action;
  }

  clear(): void {
    this.actions.clear();
    this.currentNonce = 1;
  }
}
