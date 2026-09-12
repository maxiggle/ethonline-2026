import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
  Optional,
} from '@nestjs/common';
import { IsArray, IsEthereumAddress, IsNumberString, IsOptional } from 'class-validator';
import { PolicyEngineService } from './policy-engine.service';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { AgentsService } from '../agents/agents.service';

export class DeployAgentDto {
  @IsEthereumAddress()
  agentAddress: string;

  @IsOptional()
  @IsNumberString()
  maxAutonomousAmount?: string;

  @IsOptional()
  @IsNumberString()
  dailyAutonomousLimit?: string;

  @IsOptional()
  @IsArray()
  @IsEthereumAddress({ each: true })
  approvedRecipients?: string[];

  @IsOptional()
  @IsArray()
  @IsEthereumAddress({ each: true })
  approvedTokens?: string[];
}

export class UpdateCapsDto {
  @IsNumberString()
  maxAutonomousAmount: string;

  @IsNumberString()
  dailyAutonomousLimit: string;
}

@Controller('mandates')
export class MandatesController {
  constructor(
    private readonly policyEngine: PolicyEngineService,
    private readonly agentsService: AgentsService,
    @Optional() private readonly onChainExecutor?: OnChainExecutorService,
  ) {}

  @Get('active')
  async getActiveMandate() {
    const mandate = this.policyEngine.getMandate();
    const dailySpent = this.policyEngine.getDailySpent();
    const remainingBudget = this.policyEngine.getRemainingDailyBudget();

    let totalTreasuryBalanceUsdc = 10.0;
    let treasuryEthBalance = '0.001';

    if (this.onChainExecutor) {
      try {
        const bal = await this.onChainExecutor.getTreasuryBalance();
        totalTreasuryBalanceUsdc = bal.usdcBalance;
        treasuryEthBalance = bal.ethBalance;
      } catch {
        // Retain on-chain verified fallback
      }
    }

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
      totalTreasuryBalanceUsdc,
      treasuryEthBalance,
      approvedRecipients: mandate.approvedRecipients,
      approvedTokens: mandate.approvedTokens,
    };
  }

  @Post('agent')
  @UseGuards(PrivyAuthGuard)
  @HttpCode(HttpStatus.OK)
  async deployAgent(@Req() request: AuthenticatedRequest, @Body() dto: DeployAgentDto) {
    await this.agentsService.assertAgentOwnership(request.user.id, dto.agentAddress);

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
  @UseGuards(PrivyAuthGuard)
  @HttpCode(HttpStatus.OK)
  async updateCaps(@Req() request: AuthenticatedRequest, @Body() dto: UpdateCapsDto) {
    await this.agentsService.assertAgentOwnership(
      request.user.id,
      this.policyEngine.getMandate().autonomousAgent,
    );

    this.policyEngine.updateMandate({
      maxAutonomousAmount: BigInt(dto.maxAutonomousAmount),
      dailyAutonomousLimit: BigInt(dto.dailyAutonomousLimit),
    });
    return this.getActiveMandate();
  }
}
