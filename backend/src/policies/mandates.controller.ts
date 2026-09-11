import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { PolicyEngineService } from './policy-engine.service';

export class DeployAgentDto {
  agentAddress: string;
  maxAutonomousAmount?: string;
  dailyAutonomousLimit?: string;
  approvedRecipients?: string[];
  approvedTokens?: string[];
}

export class UpdateCapsDto {
  maxAutonomousAmount: string;
  dailyAutonomousLimit: string;
}

@Controller('mandates')
export class MandatesController {
  constructor(private readonly policyEngine: PolicyEngineService) {}

  @Get('active')
  getActiveMandate() {
    const mandate = this.policyEngine.getMandate();
    const dailySpent = this.policyEngine.getDailySpent();
    const remainingBudget = this.policyEngine.getRemainingDailyBudget();

    return {
      chainId: mandate.chainId,
      safeAddress: mandate.safeAddress,
      guardAddress: mandate.guardAddress,
      autonomousAgent: mandate.autonomousAgent,
      humanSigner: mandate.humanSigner,
      maxAutonomousAmount: mandate.maxAutonomousAmount.toString(),
      dailyAutonomousLimit: mandate.dailyAutonomousLimit.toString(),
      maxAutonomousAmountUsdc: Number(mandate.maxAutonomousAmount) / 1e6,
      dailyAutonomousLimitUsdc: Number(mandate.dailyAutonomousLimit) / 1e6,
      currentDailySpentUsdc: Number(dailySpent) / 1e6,
      remainingDailyBudgetUsdc: Number(remainingBudget) / 1e6,
      approvedRecipients: mandate.approvedRecipients,
      approvedTokens: mandate.approvedTokens,
    };
  }

  @Post('agent')
  @HttpCode(HttpStatus.OK)
  deployAgent(@Body() dto: DeployAgentDto) {
    const update: any = {
      autonomousAgent: dto.agentAddress.toLowerCase(),
    };
    if (dto.maxAutonomousAmount) {
      update.maxAutonomousAmount = BigInt(dto.maxAutonomousAmount);
    }
    if (dto.dailyAutonomousLimit) {
      update.dailyAutonomousLimit = BigInt(dto.dailyAutonomousLimit);
    }
    if (dto.approvedRecipients) {
      update.approvedRecipients = dto.approvedRecipients.map((r) => r.toLowerCase());
    }
    if (dto.approvedTokens) {
      update.approvedTokens = dto.approvedTokens.map((t) => t.toLowerCase());
    }

    this.policyEngine.updateMandate(update);
    return this.getActiveMandate();
  }

  @Put('caps')
  @HttpCode(HttpStatus.OK)
  updateCaps(@Body() dto: UpdateCapsDto) {
    this.policyEngine.updateMandate({
      maxAutonomousAmount: BigInt(dto.maxAutonomousAmount),
      dailyAutonomousLimit: BigInt(dto.dailyAutonomousLimit),
    });
    return this.getActiveMandate();
  }
}
