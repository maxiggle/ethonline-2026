import { Inject, Injectable } from '@nestjs/common';
import { getAddress } from 'ethers';
import { ActionStoreService } from '../actions/action-store.service';
import { RiskAnalysisService } from '../guardian/risk-analysis.service';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { X402_CONFIG } from './x402.constants';
import { X402Config } from './x402.config';

export interface X402PaymentRequirementsInput {
  network: string;
  asset: string;
  payTo: string;
  amount: string;
}

export interface X402PolicyDecision {
  decision: GuardianDecisionType;
  riskScore: number;
  reasons: string[];
}

/**
 * Deterministic ALLOW/ESCALATE/BLOCK policy for x402 v2 payments, independent of the legacy
 * Safe/Chapter2Guard mandate (PolicyEngineService), since this rail never touches the relayer.
 */
@Injectable()
export class X402SpendingPolicyService {
  constructor(
    @Inject(X402_CONFIG) private readonly config: X402Config,
    private readonly actionStore: ActionStoreService,
    private readonly riskAnalysis: RiskAnalysisService,
  ) {}

  evaluate(
    agentAddress: string,
    requirements: X402PaymentRequirementsInput,
    justification: string,
  ): X402PolicyDecision {
    if (requirements.network !== this.config.network) {
      return {
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: [
          `Network ${requirements.network} is not the approved network ${this.config.network}`,
        ],
      };
    }

    let normalizedAsset: string;
    let normalizedPayTo: string;
    try {
      normalizedAsset = getAddress(requirements.asset);
      normalizedPayTo = getAddress(requirements.payTo);
    } catch {
      return {
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: [`Malformed asset or payTo address in payment requirements`],
      };
    }

    if (normalizedAsset !== getAddress(this.config.usdcAddress)) {
      return {
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: [`Asset ${normalizedAsset} is not the approved USDC token`],
      };
    }

    if (!this.config.approvedPayTo.includes(normalizedPayTo)) {
      return {
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons: [`Payee ${normalizedPayTo} is not on the approved recipient list`],
      };
    }

    const amount = BigInt(requirements.amount);
    const reasons: string[] = [];
    let decision = GuardianDecisionType.ALLOW;
    let riskScore = 10;

    if (amount > this.config.autonomousLimit) {
      decision = GuardianDecisionType.ESCALATE;
      riskScore = 60;
      reasons.push(
        `Amount ${amount.toString()} exceeds the autonomous limit of ${this.config.autonomousLimit.toString()}`,
      );
    } else {
      const todaysTotal = this.getTodaysApprovedTotal(agentAddress) + amount;
      if (todaysTotal > this.config.dailyLimit) {
        decision = GuardianDecisionType.ESCALATE;
        riskScore = 60;
        reasons.push(
          `Today's cumulative x402 total ${todaysTotal.toString()} would exceed the daily limit of ${this.config.dailyLimit.toString()}`,
        );
      }
    }

    const semantic = this.riskAnalysis.performMultiLayerSemanticAnalysis(justification);
    if (semantic.detectedIntents.length > 0) {
      reasons.push(
        `Adversarial justification detected: [${semantic.detectedIntents.join(', ')}]`,
      );
      riskScore = Math.max(riskScore, semantic.riskScore);
      if (decision === GuardianDecisionType.ALLOW) {
        decision = GuardianDecisionType.ESCALATE;
      }
    }

    if (decision === GuardianDecisionType.ALLOW) {
      reasons.push('Payment complies with the x402 spending policy.');
    }

    return { decision, riskScore, reasons };
  }

  private getTodaysApprovedTotal(agentAddress: string): bigint {
    const startOfDayUtc = new Date();
    startOfDayUtc.setUTCHours(0, 0, 0, 0);
    const normalizedAgent = agentAddress.toLowerCase();

    return this.actionStore
      .listActions()
      .filter(
        (action) =>
          action.agentAddress.toLowerCase() === normalizedAgent &&
          action.justification.startsWith('x402: ') &&
          (action.status === TreasuryActionStatus.APPROVED ||
            action.status === TreasuryActionStatus.EXECUTED) &&
          action.createdAt >= startOfDayUtc,
      )
      .reduce((sum, action) => sum + BigInt(action.amount), 0n);
  }
}
