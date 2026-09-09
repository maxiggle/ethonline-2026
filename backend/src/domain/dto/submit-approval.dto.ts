import { IsBoolean, IsEthereumAddress, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SubmitApprovalDto {
  @IsString()
  @IsNotEmpty()
  actionId: string;

  @IsString()
  @IsNotEmpty()
  signature: string;

  @IsEthereumAddress()
  signer: string;

  @IsOptional()
  @IsBoolean()
  biometricVerified?: boolean;
}
