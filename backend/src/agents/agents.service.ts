import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { BindAgentDto } from './dto/bind-agent.dto';
import { AgentEntity } from './interfaces/agent.interface';
import { getAddress } from 'ethers';

@Injectable()
export class AgentsService {
  private readonly logger = new Logger(AgentsService.name);

  constructor(private readonly dbService: DatabaseService) {}

  /**
   * Binds an autonomous AI agent to an authenticated user's identity.
   */
  async bindAgent(userId: string, dto: BindAgentDto): Promise<AgentEntity> {
    if (!userId) {
      throw new BadRequestException('User ID is required to bind an agent');
    }

    const agentAddress = getAddress(dto.agentAddress);
    const safeAddress = getAddress(dto.safeAddress);
    const guardAddress = getAddress(dto.guardAddress);
    const chainId = dto.chainId || 84532;
    const now = new Date().toISOString();
    const id = `agent_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    const sql = `
      INSERT INTO agent (
        id, "userId", "agentAddress", name, purpose, "safeAddress", "guardAddress", "chainId", status, "createdAt", "updatedAt"
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    await this.dbService.run(sql, [
      id,
      userId,
      agentAddress,
      dto.name,
      dto.purpose || null,
      safeAddress,
      guardAddress,
      chainId,
      'ACTIVE',
      now,
      now,
    ]);

    const created = await this.getAgentById(id);
    if (!created) {
      throw new Error('Failed to retrieve newly created agent');
    }

    this.logger.log(`Agent ${dto.name} (${agentAddress}) bound to user ${userId}`);
    return created;
  }

  /**
   * Retrieves all agents owned by a given user.
   */
  async getAgentsForUser(userId: string): Promise<AgentEntity[]> {
    const rows = await this.dbService.query<AgentEntity>(
      'SELECT * FROM agent WHERE "userId" = ? ORDER BY "createdAt" DESC',
      [userId],
    );
    return rows;
  }

  /**
   * Retrieves an agent by its unique database ID.
   */
  async getAgentById(id: string): Promise<AgentEntity | null> {
    const rows = await this.dbService.query<AgentEntity>(
      'SELECT * FROM agent WHERE id = ?',
      [id],
    );
    return rows.length > 0 ? rows[0] : null;
  }

  /**
   * Retrieves an agent by its on-chain EVM address.
   */
  async getAgentByAddress(agentAddress: string): Promise<AgentEntity | null> {
    const normalized = getAddress(agentAddress);
    const rows = await this.dbService.query<AgentEntity>(
      'SELECT * FROM agent WHERE "agentAddress" = ?',
      [normalized],
    );
    return rows.length > 0 ? rows[0] : null;
  }

  /**
   * Verifies that the specified agent address is owned and supervised by the user.
   */
  async verifyAgentOwnership(userId: string, agentAddress: string): Promise<boolean> {
    const agent = await this.getAgentByAddress(agentAddress);
    if (!agent) return false;
    return agent.userId === userId && agent.status === 'ACTIVE';
  }
}
