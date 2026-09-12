import { IsNotEmpty, IsString } from 'class-validator';

export class RejectApprovalDto {
  @IsString()
  @IsNotEmpty()
  signature: string;
}
