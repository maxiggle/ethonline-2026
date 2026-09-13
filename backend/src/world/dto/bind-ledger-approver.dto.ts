import { IsNotEmpty, IsString } from 'class-validator';

export class BindLedgerApproverDto {
  @IsString()
  @IsNotEmpty()
  signature!: string;
}
