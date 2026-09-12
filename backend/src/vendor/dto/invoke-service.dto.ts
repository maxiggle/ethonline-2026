import { IsEthereumAddress, IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';

export class InvokeServiceDto {
  @IsString()
  @IsNotEmpty()
  resourceUrl: string;

  @IsOptional()
  @IsString()
  method?: string;

  @IsOptional()
  @IsObject()
  params?: Record<string, any>;

  @IsEthereumAddress()
  agentAddress: string;
}
