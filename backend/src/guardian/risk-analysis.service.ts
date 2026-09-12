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

    if (mandate.maxAutonomousAmount === 0n || amount > mandate.maxAutonomousAmount) {
      riskScore = Math.max(riskScore, 75);
    } else {
      const fraction = Number((amount * 10000n) / mandate.maxAutonomousAmount) / 10000;
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
    const preSplit = input.replace(/[\._\-\/\\\|\+\*\^~`,;:]/g, ' ');
    const words = preSplit.split(/\s+/).filter(Boolean);

    const normalizedWords = words.map((word) => {
      // Pure numbers or percentages (e.g. "100%", "2026") are preserved without leetspeak transformation
      if (/^[0-9]+%?$/.test(word)) {
        return word.toLowerCase();
      }

      const lower = word.toLowerCase();
      let deob = '';
      let wordHasLeet = false;
      const hasLetters = /[a-z]/.test(lower);

      for (const char of lower) {
        if (LEET_SUBSTITUTION_MAP[char]) {
          deob += LEET_SUBSTITUTION_MAP[char];
          if (hasLetters || /[a-z]/.test(deob)) {
            wordHasLeet = true;
          }
        } else {
          deob += char;
        }
      }

      if (wordHasLeet) {
        wasLeetspeak = true;
        return deob;
      }
      return lower;
    });

    return {
      normalized: normalizedWords.join(' ').trim(),
      wasLeetspeak,
    };
  }

  private patternCache = new Map<readonly string[], RegExp[]>();

  private getCompiledPatterns(cluster: readonly string[]): RegExp[] {
    let patterns = this.patternCache.get(cluster);
    if (!patterns) {
      patterns = cluster.map((token) => {
        const escaped = token
          .toLowerCase()
          .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
          .replace(/ /g, '\\s+');
        return new RegExp(`(?<!\\w)${escaped}(?!\\w)`, 'i');
      });
      this.patternCache.set(cluster, patterns);
    }
    return patterns;
  }

  private containsTokenFromCluster(text: string, cluster: readonly string[]): boolean {
    const textLower = text.toLowerCase();
    const patterns = this.getCompiledPatterns(cluster);
    return patterns.some((regex) => regex.test(textLower));
  }
}
