import { GuardianDecisionType } from '../../domain/guardian-decision.entity';

export interface PolicyEvaluationResult {
  passed: boolean;
  decision: GuardianDecisionType;
  reasons: string[];
  requiresHumanApproval: boolean;
}
