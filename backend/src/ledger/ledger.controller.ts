import {
  Controller,
  Get,
  Post,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { LedgerKeyRingService } from './ledger-keyring.service';
import { SignApprovalDto } from './dto/sign-approval.dto';
import {
  LedgerDeviceStatus,
  LedgerClearSignPrompt,
  KeyRingSignResult,
} from './interfaces/ledger-keyring.interface';

@Controller('ledger')
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

  @Post('sign')
  @HttpCode(HttpStatus.OK)
  async signApproval(@Body() dto: SignApprovalDto): Promise<KeyRingSignResult> {
    return this.ledgerService.signApproval(dto, dto.domain);
  }

  @Get('keys')
  async listKeys(): Promise<{ keys: string[]; count: number }> {
    const keys = await this.ledgerService.listKeys();
    return { keys, count: keys.length };
  }
}
