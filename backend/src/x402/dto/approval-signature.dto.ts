import { IsNotEmpty, IsString } from 'class-validator';

export class ApprovalSignatureDto {
  @IsString()
  @IsNotEmpty()
  signature: string;
}
