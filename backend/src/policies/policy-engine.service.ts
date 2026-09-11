import { Injectable, Optional } from '@nestjs/common';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { TreasuryAction } from '../domain/treasury-action.entity';
import { TreasuryMandate } from '../domain/treasury-mandate.entity';
import { PolicyEvaluationResult } from './interfaces/policy-evaluation-result.interface';
import { DatabaseService } from '../database/database.service';
import { TreasuryMandateRow, DailySpentLedgerRow } from '../database/database.interface';

@Injectable()
export class PolicyEngineService {
  private readonly dbService: DatabaseService;
  private mandate: TreasuryMandate;
  private readonly dailySpentMap = new Map<number, bigint>();

  constructor(@Optional() dbService?: DatabaseService) {
    if (dbService) {
      this.dbService = dbService;
    } else {
      this.dbService = new DatabaseService();
      this.dbService.initialize(':memory:');
    }

    const safeAddress = process.env.SAFE_ADDRESS;
    if (!safeAddress) {
      throw new Error('Missing required environment variable: SAFE_ADDRESS');
    }

    const guardAddress = process.env.GUARD_ADDRESS;
    if (!guardAddress) {
      throw new Error('Missing required environment variable: GUARD_ADDRESS');
    }

    const chainId = process.env.CHAIN_ID ? Number(process.env.CHAIN_ID) : 84532;

    this.mandate = {
      chainId,
      safeAddress,
      guardAddress,
      autonomousAgent: '0x1111111111111111111111111111111111111111',
      humanSigner: '0x2222222222222222222222222222222222222222',
      maxAutonomousAmount: BigInt('100000000'),
      dailyAutonomousLimit: BigInt('500000000'),
      approvedRecipients: [
        '0x0000000000000000000000000000000000041c4e'.toLowerCase(),
        '0x00000000000000000000000000000000000000cf'.toLowerCase(),
      ],
      approvedTokens: [
        '0x0000000000000000000000000000000000000000',
        safeAddress.toLowerCase(),
      ],
    };

    this.loadFromDatabase();
  }

  private loadFromDatabase(): void {
    try {
      const row = this.dbService.getOneSync<TreasuryMandateRow>(
        'SELECT * FROM treasury_mandates WHERE chain_id = ? AND safe_address = ?',
        [this.mandate.chainId, this.mandate.safeAddress],
      );

      if (row) {
        this.mandate = {
          chainId: Number(row.chain_id),
          safeAddress: row.safe_address,
          guardAddress: row.guard_address,
          autonomousAgent: row.autonomous_agent,
          humanSigner: row.human_signer,
          maxAutonomousAmount: BigInt(row.max_autonomous_amount),
          dailyAutonomousLimit: BigInt(row.daily_autonomous_limit),
          approvedRecipients: JSON.parse(row.approved_recipients),
          approvedTokens: JSON.parse(row.approved_tokens),
        };
      } else {
        // Seed default mandate into database
        this.persistMandate();
      }

      // Load daily spent ledger
      const ledgerRows = this.dbService.querySync<DailySpentLedgerRow>(
        'SELECT * FROM daily_spent_ledger',
      );
      for (const ledger of ledgerRows) {
        this.dailySpentMap.set(Number(ledger.day_id), BigInt(ledger.cumulative_spent));
      }
    } catch {}
  }

  private persistMandate(): void {
    try {
      this.dbService.runSync(
        `INSERT OR REPLACE INTO treasury_mandates (
          chain_id, safe_address, guard_address, autonomous_agent, human_signer,
          max_autonomous_amount, daily_autonomous_limit, approved_recipients, approved_tokens, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          this.mandate.chainId,
          this.mandate.safeAddress,
          this.mandate.guardAddress,
          this.mandate.autonomousAgent,
          this.mandate.humanSigner,
          this.mandate.maxAutonomousAmount.toString(),
          this.mandate.dailyAutonomousLimit.toString(),
          JSON.stringify(this.mandate.approvedRecipients),
          JSON.stringify(this.mandate.approvedTokens),
          new Date().toISOString(),
        ],
      );
    } catch {}
  }

  public getMandate(): TreasuryMandate {
    return this.mandate;
  }

  public updateMandate(updated: Partial<TreasuryMandate>): void {
    this.mandate = { ...this.mandate, ...updated };
    this.persistMandate();
  }

  public evaluateDeterministicRules(
    action: TreasuryAction,
    timestampSeconds: number = Math.floor(Date.now() / 1000),
  ): PolicyEvaluationResult {
    const reasons: string[] = [];
    const recipientLower = action.recipient.toLowerCase();
    const tokenLower = action.token.toLowerCase();

    const isRecipientApproved = this.mandate.approvedRecipients.some(
      (r) => r.toLowerCase() === recipientLower,
    );
    if (!isRecipientApproved) {
      reasons.push(`Recipient ${action.recipient} is not on the approved whitelist.`);
      return {
        passed: false,
        decision: GuardianDecisionType.BLOCK,
        reasons,
        requiresHumanApproval: false,
      };
    }

    const isTokenApproved = this.mandate.approvedTokens.some(
      (t) => t.toLowerCase() === tokenLower,
    );
    if (!isTokenApproved) {
      reasons.push(`Token ${action.token} is not approved for treasury operations.`);
      return {
        passed: false,
        decision: GuardianDecisionType.BLOCK,
        reasons,
        requiresHumanApproval: false,
      };
    }

    const requestedAmount = BigInt(action.amount);
    const dayId = Math.floor(timestampSeconds / 86400);
    const currentDailySpent = this.getDailySpent(timestampSeconds);

    if (requestedAmount > this.mandate.maxAutonomousAmount) {
      reasons.push(
        `Requested amount (${action.amount}) exceeds single autonomous limit (${this.mandate.maxAutonomousAmount.toString()}).`,
      );
      return {
        passed: false,
        decision: GuardianDecisionType.ESCALATE,
        reasons,
        requiresHumanApproval: true,
      };
    }

    if (currentDailySpent + requestedAmount > this.mandate.dailyAutonomousLimit) {
      reasons.push(
        `Cumulative daily spend (${(currentDailySpent + requestedAmount).toString()}) exceeds daily autonomous limit (${this.mandate.dailyAutonomousLimit.toString()}).`,
      );
      return {
        passed: false,
        decision: GuardianDecisionType.ESCALATE,
        reasons,
        requiresHumanApproval: true,
      };
    }

    reasons.push('Transaction complies with all deterministic mandate constraints.');
    return {
      passed: true,
      decision: GuardianDecisionType.ALLOW,
      reasons,
      requiresHumanApproval: false,
    };
  }

  public recordAutonomousSpend(
    amount: string,
    timestampSeconds: number = Math.floor(Date.now() / 1000),
  ): void {
    const dayId = Math.floor(timestampSeconds / 86400);
    const current = this.getDailySpent(timestampSeconds);
    const updated = current + BigInt(amount);
    this.dailySpentMap.set(dayId, updated);

    try {
      this.dbService.runSync(
        `INSERT OR REPLACE INTO daily_spent_ledger (day_id, cumulative_spent, updated_at)
         VALUES (?, ?, ?)`,
        [dayId, updated.toString(), new Date().toISOString()],
      );
    } catch {}
  }

  public getDailySpent(timestampSeconds: number = Math.floor(Date.now() / 1000)): bigint {
    const dayId = Math.floor(timestampSeconds / 86400);
    const inMemory = this.dailySpentMap.get(dayId);
    if (inMemory !== undefined) {
      return inMemory;
    }

    try {
      const row = this.dbService.getOneSync<DailySpentLedgerRow>(
        'SELECT * FROM daily_spent_ledger WHERE day_id = ?',
        [dayId],
      );
      if (row) {
        const val = BigInt(row.cumulative_spent);
        this.dailySpentMap.set(dayId, val);
        return val;
      }
    } catch {}

    return BigInt(0);
  }

  public getRemainingDailyBudget(timestampSeconds: number = Math.floor(Date.now() / 1000)): bigint {
    const spent = this.getDailySpent(timestampSeconds);
    if (spent >= this.mandate.dailyAutonomousLimit) {
      return BigInt(0);
    }
    return this.mandate.dailyAutonomousLimit - spent;
  }
}
