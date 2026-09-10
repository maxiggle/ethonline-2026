import { IsEthereumAddress, IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';
import { Eip712Domain } from '../../crypto/interfaces/eip712.interface';

export class SignApprovalDto {
  @IsString()
  @IsNotEmpty()
  actionId: string;

  @IsEthereumAddress()
  agent: string;

  @IsEthereumAddress()
  recipient: string;

  @IsEthereumAddress()
  token: string;

  @IsString()
  @IsNotEmpty()
  amount: string;

  @IsNumber()
  nonce: number;

  @IsNumber()
  deadline: number;

  @IsString()
  @IsNotEmpty()
  mandateHash: string;

  @IsNumber()
  riskScore: number;

  @IsOptional()
  domain?: Eip712Domain;
}
