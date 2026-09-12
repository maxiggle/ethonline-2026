import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AgentsService } from './agents.service';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { BindAgentDto } from './dto/bind-agent.dto';

@Controller('agents')
@UseGuards(PrivyAuthGuard)
export class AgentsController {
  constructor(private readonly agentsService: AgentsService) {}

  /**
   * Binds an autonomous AI agent and its associated Safe Multisig to the authenticated user.
   */
  @Post('bind')
  @HttpCode(HttpStatus.CREATED)
  async bindAgent(@Body() dto: BindAgentDto, @Req() req: any) {
    const userId = req.user.id;
    const agent = await this.agentsService.bindAgent(userId, dto);
    return {
      success: true,
      message: 'Agent successfully bound to user identity',
      agent,
    };
  }

  /**
   * Retrieves all autonomous agents bound to the authenticated user.
   */
  @Get()
  async getMyAgents(@Req() req: any) {
    const userId = req.user.id;
    const agents = await this.agentsService.ensureDefaultAgentForUser(userId);
    return {
      success: true,
      agents,
    };
  }
}
