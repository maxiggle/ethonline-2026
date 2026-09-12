import { Type } from 'class-transformer';
import { IsNotEmpty, IsObject, IsString, ValidateNested } from 'class-validator';

export class PaymentRequirementsDto {
  @IsString()
  @IsNotEmpty()
  scheme: string;

  @IsString()
  @IsNotEmpty()
  network: string;

  @IsString()
  @IsNotEmpty()
  asset: string;

  @IsString()
  @IsNotEmpty()
  amount: string;

  @IsString()
  @IsNotEmpty()
  payTo: string;
}

export class AuthorizePaymentDto {
  @IsString()
  @IsNotEmpty()
  resourceUrl: string;

  @IsObject()
  @ValidateNested()
  @Type(() => PaymentRequirementsDto)
  paymentRequirements: PaymentRequirementsDto;

  @IsString()
  @IsNotEmpty()
  justification: string;
}
