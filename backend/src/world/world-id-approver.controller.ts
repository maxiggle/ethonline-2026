import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { BindLedgerApproverDto } from './dto/bind-ledger-approver.dto';
import {
  ApproverStatus,
  OrbVerification,
  WorldIdApproverService,
} from './world-id-approver.service';

@Controller('world/approver')
@UseGuards(PrivyAuthGuard)
export class WorldIdApproverController {
  constructor(private readonly approverService: WorldIdApproverService) {}

  @Get('status')
  async getStatus(): Promise<ApproverStatus> {
    return this.approverService.getApproverStatus();
  }

  @Post('orb-verifications')
  @HttpCode(HttpStatus.CREATED)
  async startOrbVerification(
    @Req() request: AuthenticatedRequest,
  ): Promise<OrbVerification> {
    return this.approverService.startOrbVerification(request.user.id);
  }

  @Get('orb-verifications/:requestId')
  async getOrbVerification(
    @Req() request: AuthenticatedRequest,
    @Param('requestId') requestId: string,
  ): Promise<OrbVerification> {
    return this.approverService.getOrbVerification(request.user.id, requestId);
  }

  @Post('orb-verifications/:requestId/bind')
  @HttpCode(HttpStatus.OK)
  async bindLedgerApprover(
    @Req() request: AuthenticatedRequest,
    @Param('requestId') requestId: string,
    @Body() dto: BindLedgerApproverDto,
  ): Promise<ApproverStatus> {
    return this.approverService.bindLedgerApprover(
      request.user.id,
      requestId,
      dto.signature,
    );
  }
}
