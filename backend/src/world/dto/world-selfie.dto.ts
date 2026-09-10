import { IsEthereumAddress, IsNotEmpty, IsObject, IsOptional } from 'class-validator';
import { WorldIdSelfieProof } from '../interfaces/world-selfie.interface';

export class VerifySelfieDto {
  @IsObject()
  @IsNotEmpty()
  proofPayload: WorldIdSelfieProof;

  @IsOptional()
  @IsEthereumAddress()
  expectedSigner?: string;
}

export class BindSelfieDto {
  @IsEthereumAddress()
  @IsNotEmpty()
  signerAddress: string;

  @IsObject()
  @IsNotEmpty()
  proofPayload: WorldIdSelfieProof;
}
