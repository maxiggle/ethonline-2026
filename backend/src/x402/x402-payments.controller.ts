import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AgentSignatureGuard } from './guards/agent-signature.guard';
import { AuthenticatedAgentRequest } from './interfaces/authenticated-agent-request.interface';
import { X402PaymentsService } from './x402-payments.service';
import { AuthorizePaymentDto } from './dto/authorize-payment.dto';
import { SubmitEscalationDto } from './dto/submit-escalation.dto';
import { SubmitSettlementDto } from './dto/submit-settlement.dto';
import { ApprovalSignatureDto } from './dto/approval-signature.dto';
import { RejectApprovalDto } from './dto/reject-approval.dto';

/**
 * Guardian-gated x402 payments API. Agent routes authenticate with a Key Ring-protected wallet
 * signature (AgentSignatureGuard); approval-console routes are public reads plus Ledger-signed
 * writes — every state change on an escalation requires a signature that recovers to
 * LEDGER_APPROVER_ADDRESS, so publishing the pending list itself grants no authority.
 */
@Controller('x402')
export class X402PaymentsController {
  constructor(private readonly paymentsService: X402PaymentsService) {}

  @Post('payments/authorize')
  @UseGuards(AgentSignatureGuard)
  async authorize(@Req() request: AuthenticatedAgentRequest, @Body() dto: AuthorizePaymentDto) {
    return this.paymentsService.authorize(request.agent, dto);
  }

  @Post('payments/:actionId/escalation')
  @UseGuards(AgentSignatureGuard)
  async submitEscalation(
    @Req() request: AuthenticatedAgentRequest,
    @Param('actionId') actionId: string,
    @Body() dto: SubmitEscalationDto,
  ) {
    return this.paymentsService.submitEscalation(request.agent, actionId, dto.typedData);
  }

  @Get('payments/:actionId')
  @UseGuards(AgentSignatureGuard)
  async getPayment(@Req() request: AuthenticatedAgentRequest, @Param('actionId') actionId: string) {
    return this.paymentsService.getPaymentStatus(request.agent, actionId);
  }

  @Post('payments/:actionId/settlement')
  @UseGuards(AgentSignatureGuard)
  async settle(
    @Req() request: AuthenticatedAgentRequest,
    @Param('actionId') actionId: string,
    @Body() dto: SubmitSettlementDto,
  ) {
    return this.paymentsService.settle(request.agent, actionId, dto.transactionHash);
  }

  @Get('approvals/config')
  getApprovalConfig() {
    return this.paymentsService.getApprovalConfig();
  }

  @Get('approvals/pending')
  async getPendingApprovals() {
    return this.paymentsService.listPendingApprovals();
  }

  @Post('approvals/:actionId/signature')
  async approve(@Param('actionId') actionId: string, @Body() dto: ApprovalSignatureDto) {
    return this.paymentsService.approveWithSignature(actionId, dto.signature);
  }

  @Post('approvals/:actionId/reject')
  async reject(@Param('actionId') actionId: string, @Body() dto: RejectApprovalDto) {
    return this.paymentsService.rejectWithSignature(actionId, dto.signature);
  }
}
