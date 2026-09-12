import { Injectable, Optional } from '@nestjs/common';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { DatabaseService } from '../database/database.service';
import { TreasuryActionRow } from '../database/database.interface';

@Injectable()
export class ActionStoreService {
  private readonly dbService: DatabaseService;
  private readonly actions = new Map<string, TreasuryAction>();
  private currentNonce = 1;

  constructor(@Optional() dbService?: DatabaseService) {
    if (dbService) {
      this.dbService = dbService;
    } else {
      this.dbService = new DatabaseService();
      this.dbService.initialize(':memory:');
    }
    this.loadFromDatabase();
  }

  private mapRowToAction(row: TreasuryActionRow): TreasuryAction {
    return {
      id: row.id,
      target: row.target,
      value: row.value,
      data: row.data,
      token: row.token,
      recipient: row.recipient,
      amount: row.amount,
      agentAddress: row.agent_address,
      justification: row.justification,
      status: row.status as TreasuryActionStatus,
      nonce: Number(row.nonce),
      deadline: Number(row.deadline),
      riskScore: Number(row.risk_score),
      requiresHumanApproval: Boolean(row.requires_human_approval),
      signature: row.signature || undefined,
      txHash: row.tx_hash || undefined,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }

  private loadFromDatabase(): void {
    try {
      const rows = this.dbService.querySync<TreasuryActionRow>(
        'SELECT * FROM treasury_actions ORDER BY nonce ASC',
      );
      for (const row of rows) {
        const action = this.mapRowToAction(row);
        this.actions.set(action.id, action);
        if (action.nonce >= this.currentNonce) {
          this.currentNonce = action.nonce + 1;
        }
      }
    } catch {}
  }

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

    try {
      this.dbService.runSync(
        `INSERT INTO treasury_actions (
          id, target, value, data, token, recipient, amount, agent_address,
          justification, status, risk_score, requires_human_approval, nonce,
          deadline, signature, tx_hash, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          action.id,
          action.target,
          action.value,
          action.data,
          action.token,
          action.recipient,
          action.amount,
          action.agentAddress,
          action.justification,
          action.status,
          action.riskScore,
          action.requiresHumanApproval ? 1 : 0,
          action.nonce,
          action.deadline,
          action.signature || null,
          action.txHash || null,
          action.createdAt.toISOString(),
          action.updatedAt.toISOString(),
        ],
      );
    } catch {}

    return action;
  }

  getAction(id: string): TreasuryAction | undefined {
    let action = this.actions.get(id);
    if (!action) {
      try {
        const row = this.dbService.getOneSync<TreasuryActionRow>(
          'SELECT * FROM treasury_actions WHERE id = ?',
          [id],
        );
        if (row) {
          action = this.mapRowToAction(row);
          this.actions.set(action.id, action);
        }
      } catch {}
    }
    return action;
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
    const action = this.getAction(id);
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

    try {
      this.dbService.runSync(
        `UPDATE treasury_actions
         SET status = ?, signature = ?, tx_hash = ?, updated_at = ?
         WHERE id = ?`,
        [
          action.status,
          action.signature || null,
          action.txHash || null,
          action.updatedAt.toISOString(),
          id,
        ],
      );
    } catch {}

    return action;
  }

  clear(): void {
    this.actions.clear();
    this.currentNonce = 1;
    try {
      this.dbService.runSync('DELETE FROM treasury_actions');
    } catch {}
  }
}
