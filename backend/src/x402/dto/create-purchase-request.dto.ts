import { IsNotEmpty, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreatePurchaseRequestDto {
  @IsString()
  @IsNotEmpty()
  agentAddress: string;

  @IsString()
  @IsNotEmpty()
  resourceUrl: string;

  @IsOptional()
  @IsObject()
  queryParams?: Record<string, unknown>;

  @IsString()
  @IsNotEmpty()
  @MaxLength(280)
  justification: string;
}
