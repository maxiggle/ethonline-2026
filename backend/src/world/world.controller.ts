import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Req,
  UseGuards,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { getAddress, isAddress } from 'ethers';
import { WorldSelfieService } from './world-selfie.service';
import { VerifySelfieDto, BindSelfieDto } from './dto/world-selfie.dto';
import { SelfieVerificationResult, HumanBinding } from './interfaces/world-selfie.interface';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';

@Controller('world/selfie')
@UseGuards(PrivyAuthGuard)
export class WorldController {
  constructor(private readonly worldSelfieService: WorldSelfieService) {}

  private normalizeAddress(address: string): string {
    if (!isAddress(address)) {
      throw new BadRequestException(`Invalid Ethereum address: ${address}`);
    }
    return getAddress(address);
  }

  private resolveCallerWallet(request: AuthenticatedRequest): string {
    if (!request.user.walletAddress) {
      throw new ForbiddenException('Authenticated user has no embedded wallet address');
    }
    return this.normalizeAddress(request.user.walletAddress);
  }

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
    @Req() request: AuthenticatedRequest,
    @Body() dto: BindSelfieDto,
  ): Promise<HumanBinding> {
    const callerWallet = this.resolveCallerWallet(request);
    if (this.normalizeAddress(dto.signerAddress) !== callerWallet) {
      throw new ForbiddenException(
        `World ID bindings can only be created for the authenticated wallet ${callerWallet}`,
      );
    }

    return this.worldSelfieService.bindHumanSigner(callerWallet, dto.proofPayload);
  }

  @Get('status/:signerAddress')
  async getVerificationStatus(@Param('signerAddress') signerAddress: string): Promise<{
    signerAddress: string;
    isVerified: boolean;
    binding?: HumanBinding | null;
  }> {
    const normalizedSigner = this.normalizeAddress(signerAddress);
    const isVerified = await this.worldSelfieService.isHumanSignerVerified(normalizedSigner);
    const binding = await this.worldSelfieService.getHumanBinding(normalizedSigner);

    return {
      signerAddress: normalizedSigner,
      isVerified,
      binding,
    };
  }

  @Get('bindings')
  async getCallerBindings(@Req() request: AuthenticatedRequest): Promise<HumanBinding[]> {
    const binding = await this.worldSelfieService.getHumanBinding(this.resolveCallerWallet(request));
    return binding ? [binding] : [];
  }

  @Delete('bindings/:signerAddress')
  async revokeBinding(
    @Req() request: AuthenticatedRequest,
    @Param('signerAddress') signerAddress: string,
  ): Promise<{
    signerAddress: string;
    revoked: boolean;
  }> {
    const callerWallet = this.resolveCallerWallet(request);
    const normalizedSigner = this.normalizeAddress(signerAddress);
    if (normalizedSigner !== callerWallet) {
      throw new ForbiddenException('Only the bound wallet can revoke its World ID binding');
    }

    const existing = await this.worldSelfieService.getHumanBinding(normalizedSigner);
    if (!existing) {
      throw new NotFoundException(`No active binding found for ${normalizedSigner}`);
    }

    await this.worldSelfieService.revokeHumanBinding(normalizedSigner);

    return {
      signerAddress: normalizedSigner,
      revoked: true,
    };
  }
}
