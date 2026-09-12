import {
  Controller,
  Get,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { LedgerKeyRingService } from './ledger-keyring.service';
import { SignApprovalDto } from './dto/sign-approval.dto';
import {
  LedgerDeviceStatus,
  LedgerClearSignPrompt,
} from './interfaces/ledger-keyring.interface';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';

/**
 * Escalated approvals must be clear-signed on the human signer's own device, so this controller
 * deliberately exposes no endpoint that signs an approval on a caller's behalf.
 */
@Controller('ledger')
@UseGuards(PrivyAuthGuard)
export class LedgerController {
  constructor(private readonly ledgerService: LedgerKeyRingService) {}

  @Get('status')
  async getStatus(): Promise<LedgerDeviceStatus> {
    return this.ledgerService.getStatus();
  }

  @Get('signer')
  async getSignerAddress(): Promise<{ address: string }> {
    const address = await this.ledgerService.getSignerAddress();
    return { address };
  }

  @Post('clear-sign-prompt')
  @HttpCode(HttpStatus.OK)
  formatClearSignPrompt(@Body() dto: SignApprovalDto): LedgerClearSignPrompt {
    return this.ledgerService.formatClearSignPrompt(dto, dto.domain);
  }

  @Get('keys')
  async listKeys(): Promise<{ keys: string[]; count: number }> {
    const keys = await this.ledgerService.listKeys();
    return { keys, count: keys.length };
  }
}
