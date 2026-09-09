import { TreasuryAction } from '../treasury-action.entity';
import { GuardianDecision } from '../guardian-decision.entity';

export class ActionResponseDto {
  action: TreasuryAction;
  decision: GuardianDecision;
  typedData?: Record<string, any>;
}
