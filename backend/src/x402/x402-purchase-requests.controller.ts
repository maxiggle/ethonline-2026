import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Req, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { AgentSignatureGuard } from './guards/agent-signature.guard';
import { AuthenticatedAgentRequest } from './interfaces/authenticated-agent-request.interface';
import { X402PurchaseRequestsService } from './x402-purchase-requests.service';
import { CreatePurchaseRequestDto } from './dto/create-purchase-request.dto';
import { ReportPurchaseRequestProgressDto } from './dto/report-purchase-request-progress.dto';
import { ReportPurchaseRequestResultDto } from './dto/report-purchase-request-result.dto';

/**
 * The app queues purchase requests for its agent to pay; the agent worker (authenticated the same
 * way as `/x402/payments/*`, via `AgentSignatureGuard`) claims and resolves them. The agent's key
 * never touches the backend — every payment still goes through the Guardian-gated x402 flow.
 */
@Controller('x402/purchase-requests')
export class X402PurchaseRequestsController {
  constructor(private readonly purchaseRequestsService: X402PurchaseRequestsService) {}

  @Post()
  @UseGuards(PrivyAuthGuard)
  @HttpCode(HttpStatus.CREATED)
  async create(@Req() request: AuthenticatedRequest, @Body() dto: CreatePurchaseRequestDto) {
    return this.purchaseRequestsService.createRequest(request.user.id, dto);
  }

  @Get()
  @UseGuards(PrivyAuthGuard)
  async list(@Req() request: AuthenticatedRequest) {
    return this.purchaseRequestsService.listForUser(request.user.id);
  }

  @Post('claim')
  @UseGuards(AgentSignatureGuard)
  async claim(@Req() request: AuthenticatedAgentRequest, @Res({ passthrough: true }) response: Response) {
    const claimed = await this.purchaseRequestsService.claim(request.agent);
    if (!claimed) {
      response.status(HttpStatus.NO_CONTENT);
      return undefined;
    }
    response.status(HttpStatus.OK);
    return claimed;
  }

  @Get(':id')
  @UseGuards(PrivyAuthGuard)
  async getOne(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    return this.purchaseRequestsService.getForUser(request.user.id, id);
  }

  @Post(':id/progress')
  @UseGuards(AgentSignatureGuard)
  async reportProgress(
    @Req() request: AuthenticatedAgentRequest,
    @Param('id') id: string,
    @Body() dto: ReportPurchaseRequestProgressDto,
  ) {
    return this.purchaseRequestsService.reportProgress(request.agent, id, dto);
  }

  @Post(':id/result')
  @UseGuards(AgentSignatureGuard)
  async reportResult(
    @Req() request: AuthenticatedAgentRequest,
    @Param('id') id: string,
    @Body() dto: ReportPurchaseRequestResultDto,
  ) {
    return this.purchaseRequestsService.reportResult(request.agent, id, dto);
  }
}
