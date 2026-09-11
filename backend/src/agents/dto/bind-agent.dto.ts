import { IsNotEmpty, IsString, IsOptional, IsNumber, Matches } from 'class-validator';

export class BindAgentDto {
  @IsNotEmpty()
  @IsString()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'agentAddress must be a valid 20-byte EVM address' })
  agentAddress: string;

  @IsNotEmpty()
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  purpose?: string;

  @IsNotEmpty()
  @IsString()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'safeAddress must be a valid 20-byte EVM address' })
  safeAddress: string;

  @IsNotEmpty()
  @IsString()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'guardAddress must be a valid 20-byte EVM address' })
  guardAddress: string;

  @IsOptional()
  @IsNumber()
  chainId?: number;
}
