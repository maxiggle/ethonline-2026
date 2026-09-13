import { IsArray, IsIn, IsObject, IsOptional, IsString, Matches } from 'class-validator';
import { GuardianDecisionType } from '../../domain/guardian-decision.entity';

export const PURCHASE_REQUEST_RESULT_STATUSES = ['PAID', 'BLOCKED', 'REJECTED', 'EXPIRED', 'FAILED'] as const;
export type PurchaseRequestResultStatus = (typeof PURCHASE_REQUEST_RESULT_STATUSES)[number];

export class ReportPurchaseRequestResultDto {
  @IsIn(PURCHASE_REQUEST_RESULT_STATUSES)
  status: PurchaseRequestResultStatus;

  @IsOptional()
  @IsString()
  actionId?: string;

  @IsOptional()
  @IsIn([GuardianDecisionType.ALLOW, GuardianDecisionType.ESCALATE, GuardianDecisionType.BLOCK])
  decision?: GuardianDecisionType;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  reasons?: string[];

  @IsOptional()
  @Matches(/^0x[0-9a-fA-F]{64}$/, {
    message: 'transactionHash must be a 32-byte hex-encoded transaction hash',
  })
  transactionHash?: string;

  @IsOptional()
  @IsObject()
  response?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  error?: string;
}
