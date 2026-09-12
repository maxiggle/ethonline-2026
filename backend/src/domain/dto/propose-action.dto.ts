import { IsEthereumAddress, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class ProposeActionDto {
  @IsEthereumAddress()
  target: string;

  @IsString()
  value: string;

  @IsString()
  data: string;

  @IsEthereumAddress()
  token: string;

  @IsEthereumAddress()
  recipient: string;

  @IsString()
  amount: string;

  @IsEthereumAddress()
  agentAddress: string;

  @IsString()
  @IsNotEmpty()
  justification: string;

  @IsOptional()
  worldIdProof?: Record<string, any>;
}
