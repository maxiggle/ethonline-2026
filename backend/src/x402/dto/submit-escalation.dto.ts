import { IsNotEmpty, IsObject } from 'class-validator';

export class SubmitEscalationDto {
  @IsObject()
  @IsNotEmpty()
  typedData: Record<string, any>;
}
