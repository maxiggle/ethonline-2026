import { Injectable } from '@nestjs/common';
import { GuardianDecision, GuardianDecisionType } from '../domain/guardian-decision.entity';
import { TreasuryAction } from '../domain/treasury-action.entity';
import { PolicyEngineService } from '../policies/policy-engine.service';
import {
  EXFILTRATION_INTENT_TOKENS,
  LEET_SUBSTITUTION_MAP,
  SUBVERSION_INTENT_TOKENS,
  TARGET_CONSTRAINT_TOKENS,
} from '../common/adversarial-patterns.constants';
import { SemanticAnalysisResult } from './interfaces/semantic-analysis-result.interface';

@Injectable()
export class RiskAnalysisService {
  constructor(private readonly policyEngine: PolicyEngineService) {}

  public async evaluateAction(action: TreasuryAction): Promise<GuardianDecision> {
    const deterministicResult = this.policyEngine.evaluateDeterministicRules(action);
    const reasons = [...deterministicResult.reasons];

    const semantic = this.performMultiLayerSemanticAnalysis(action.justification);
    let riskScore = semantic.riskScore;

    if (semantic.detectedIntents.length > 0) {
      reasons.push(
        `Multi-tier adversarial analysis flagged suspicious intents: [${semantic.detectedIntents.join(', ')}] (Confidence: ${(semantic.semanticClassifierConfidence * 100).toFixed(0)}%).`,
      );
    }

    const amount = BigInt(action.amount);
    const mandate = this.policyEngine.getMandate();

    if (amount > mandate.maxAutonomousAmount) {
      riskScore = Math.max(riskScore, 75);
    } else {
      const fraction = Number(amount) / Number(mandate.maxAutonomousAmount);
      riskScore += Math.floor(fraction * 25);
    }

    if (deterministicResult.decision === GuardianDecisionType.BLOCK) {
      return {
        actionId: action.id,
        decision: GuardianDecisionType.BLOCK,
        riskScore: 100,
        reasons,
        deterministicPassed: false,
        requiresHumanApproval: false,
        evaluatedAt: new Date(),
      };
    }

    if (deterministicResult.decision === GuardianDecisionType.ESCALATE) {
      return {
        actionId: action.id,
        decision: GuardianDecisionType.ESCALATE,
        riskScore: Math.max(riskScore, 75),
        reasons,
        deterministicPassed: false,
        requiresHumanApproval: true,
        evaluatedAt: new Date(),
      };
    }

    if (riskScore >= 50) {
      reasons.push(
        'Adversarial / semantic risk elevation triggered. Hard on-chain escalation enforced.',
      );
      return {
        actionId: action.id,
        decision: GuardianDecisionType.ESCALATE,
        riskScore,
        reasons,
        deterministicPassed: true,
        requiresHumanApproval: true,
        evaluatedAt: new Date(),
      };
    }

    return {
      actionId: action.id,
      decision: GuardianDecisionType.ALLOW,
      riskScore,
      reasons,
      deterministicPassed: true,
      requiresHumanApproval: false,
      evaluatedAt: new Date(),
    };
  }

  public performMultiLayerSemanticAnalysis(text: string): SemanticAnalysisResult {
    if (!text || text.trim().length === 0) {
      return {
        riskScore: 0,
        detectedIntents: [],
        normalizedContent: '',
        leetspeakNormalized: false,
        semanticClassifierConfidence: 0,
      };
    }

    const { normalized, wasLeetspeak } = this.normalizeText(text);
    const detectedIntents: string[] = [];
    let cumulativeRisk = 0;

    const hasSubversion = this.containsTokenFromCluster(normalized, SUBVERSION_INTENT_TOKENS);
    const hasTargetConstraint = this.containsTokenFromCluster(
      normalized,
      TARGET_CONSTRAINT_TOKENS,
    );

    if (hasSubversion && hasTargetConstraint) {
      detectedIntents.push('INSTRUCTION_SUBVERSION_ATTEMPT');
      cumulativeRisk += 70;
    }

    const hasExfiltration = this.containsTokenFromCluster(
      normalized,
      EXFILTRATION_INTENT_TOKENS,
    );
    if (hasExfiltration) {
      detectedIntents.push('TREASURY_DRAIN_EXFILTRATION_INTENT');
      cumulativeRisk += 65;
    }

    if (wasLeetspeak && (hasSubversion || hasExfiltration)) {
      detectedIntents.push('OBFUSCATION_EVASION_TECHNIQUE');
      cumulativeRisk += 15;
    }

    const confidence =
      detectedIntents.length > 0 ? Math.min(0.98, 0.65 + detectedIntents.length * 0.15) : 0.1;

    return {
      riskScore: Math.min(100, cumulativeRisk),
      detectedIntents,
      normalizedContent: normalized,
      leetspeakNormalized: wasLeetspeak,
      semanticClassifierConfidence: confidence,
    };
  }

  public normalizeText(input: string): { normalized: string; wasLeetspeak: boolean } {
    let wasLeetspeak = false;
    const lower = input.toLowerCase();

    let deobfuscated = '';
    for (let i = 0; i < lower.length; i++) {
      const char = lower[i];
      if (LEET_SUBSTITUTION_MAP[char]) {
        deobfuscated += LEET_SUBSTITUTION_MAP[char];
        wasLeetspeak = true;
      } else {
        deobfuscated += char;
      }
    }

    const strippedSeparators = deobfuscated
      .replace(/[\._\-\/\\\|\+\*\^~`]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    return { normalized: strippedSeparators, wasLeetspeak };
  }

  private containsTokenFromCluster(text: string, cluster: readonly string[]): boolean {
    const textLower = text.toLowerCase();
    return cluster.some((token) => {
      const regex = new RegExp(`\\b${token.replace(/ /g, '\\s+')}\\b`, 'i');
      return regex.test(textLower) || textLower.includes(token);
    });
  }
}
