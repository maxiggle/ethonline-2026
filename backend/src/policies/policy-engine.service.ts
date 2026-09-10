import { Injectable } from '@nestjs/common';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { TreasuryAction } from '../domain/treasury-action.entity';
import { TreasuryMandate } from '../domain/treasury-mandate.entity';
import { PolicyEvaluationResult } from './interfaces/policy-evaluation-result.interface';

@Injectable()
export class PolicyEngineService {
  private mandate: TreasuryMandate = {
    chainId: 84532,
    safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
    guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
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
      '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6'.toLowerCase(),
    ],
  };

  private dailySpentMap = new Map<number, bigint>();

  public getMandate(): TreasuryMandate {
    return this.mandate;
  }

  public updateMandate(updated: Partial<TreasuryMandate>): void {
    this.mandate = { ...this.mandate, ...updated };
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
    const currentDailySpent = this.dailySpentMap.get(dayId) || BigInt(0);

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

  public recordAutonomousSpend(amount: string, timestampSeconds: number = Math.floor(Date.now() / 1000)): void {
    const dayId = Math.floor(timestampSeconds / 86400);
    const current = this.dailySpentMap.get(dayId) || BigInt(0);
    this.dailySpentMap.set(dayId, current + BigInt(amount));
  }

  public getDailySpent(timestampSeconds: number = Math.floor(Date.now() / 1000)): bigint {
    const dayId = Math.floor(timestampSeconds / 86400);
    return this.dailySpentMap.get(dayId) || BigInt(0);
  }

  public getRemainingDailyBudget(timestampSeconds: number = Math.floor(Date.now() / 1000)): bigint {
    const spent = this.getDailySpent(timestampSeconds);
    if (spent >= this.mandate.dailyAutonomousLimit) {
      return BigInt(0);
    }
    return this.mandate.dailyAutonomousLimit - spent;
  }
}
