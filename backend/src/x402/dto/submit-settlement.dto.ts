import { Matches } from 'class-validator';

export class SubmitSettlementDto {
  @Matches(/^0x[0-9a-fA-F]{64}$/, {
    message: 'transactionHash must be a 32-byte hex-encoded transaction hash',
  })
  transactionHash: string;
}
