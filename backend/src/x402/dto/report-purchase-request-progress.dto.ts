import { IsArray, IsIn, IsNotEmpty, IsString } from 'class-validator';
import { GuardianDecisionType } from '../../domain/guardian-decision.entity';

export class ReportPurchaseRequestProgressDto {
  @IsString()
  @IsNotEmpty()
  actionId: string;

  @IsIn([GuardianDecisionType.ALLOW, GuardianDecisionType.ESCALATE, GuardianDecisionType.BLOCK])
  decision: GuardianDecisionType;

  @IsArray()
  @IsString({ each: true })
  reasons: string[];
}
