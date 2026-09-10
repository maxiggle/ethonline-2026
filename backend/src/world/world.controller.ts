import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  NotFoundException,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { WorldSelfieService } from './world-selfie.service';
import { VerifySelfieDto, BindSelfieDto } from './dto/world-selfie.dto';
import { SelfieVerificationResult, HumanBinding } from './interfaces/world-selfie.interface';

@Controller('world/selfie')
export class WorldController {
  constructor(private readonly worldSelfieService: WorldSelfieService) {}

  @Post('verify')
  @HttpCode(HttpStatus.OK)
  async verifySelfie(
    @Body() dto: VerifySelfieDto,
  ): Promise<SelfieVerificationResult> {
    return this.worldSelfieService.verifySelfieProof(
      dto.proofPayload,
      dto.expectedSigner,
    );
  }

  @Post('bind')
  @HttpCode(HttpStatus.CREATED)
  async bindHumanSigner(
    @Body() dto: BindSelfieDto,
  ): Promise<HumanBinding> {
    return this.worldSelfieService.bindHumanSigner(
      dto.signerAddress,
      dto.proofPayload,
    );
  }

  @Get('status/:signerAddress')
  async getVerificationStatus(@Param('signerAddress') signerAddress: string): Promise<{
    signerAddress: string;
    isVerified: boolean;
    binding?: HumanBinding | null;
  }> {
    const isVerified = await this.worldSelfieService.isHumanSignerVerified(signerAddress);
    const binding = await this.worldSelfieService.getHumanBinding(signerAddress);

    return {
      signerAddress,
      isVerified,
      binding,
    };
  }

  @Get('bindings')
  async getAllBindings(): Promise<HumanBinding[]> {
    return this.worldSelfieService.getAllBindings();
  }

  @Delete('bindings/:signerAddress')
  async revokeBinding(@Param('signerAddress') signerAddress: string): Promise<{
    signerAddress: string;
    revoked: boolean;
  }> {
    const existing = await this.worldSelfieService.getHumanBinding(signerAddress);
    if (!existing) {
      throw new NotFoundException(`No active binding found for ${signerAddress}`);
    }

    await this.worldSelfieService.revokeHumanBinding(signerAddress);

    return {
      signerAddress,
      revoked: true,
    };
  }
}
