export enum GuardianDecisionType {
  ALLOW = 'ALLOW',
  ESCALATE = 'ESCALATE',
  BLOCK = 'BLOCK',
}

export class GuardianDecision {
  actionId: string;
  decision: GuardianDecisionType;
  riskScore: number;
  reasons: string[];
  deterministicPassed: boolean;
  requiresHumanApproval: boolean;
  signature?: string;
  evaluatedAt: Date;
}
