import { Injectable, Logger, BadRequestException, NotFoundException, Optional } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { BindAgentDto } from './dto/bind-agent.dto';
import { AgentEntity } from './interfaces/agent.interface';
import { getAddress } from 'ethers';

@Injectable()
export class AgentsService {
  private readonly logger = new Logger(AgentsService.name);

  constructor(
    private readonly dbService: DatabaseService,
    @Optional() private readonly onChainExecutor?: OnChainExecutorService,
  ) {}

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

    // Update active mandate in database to recognize this autonomous agent
    try {
      await this.dbService.run(
        'UPDATE treasury_mandates SET autonomous_agent = ?, updated_at = ? WHERE safe_address = ?',
        [agentAddress, now, safeAddress],
      );
    } catch (err: any) {
      this.logger.debug(`Could not update mandate autonomous_agent: ${err.message}`);
    }

    // Synchronize with live on-chain Chapter2Guard contract if executor is configured
    if (this.onChainExecutor) {
      try {
        await this.onChainExecutor.setAutonomousAgent(agentAddress);
        this.logger.log(`On-chain Chapter2Guard updated with autonomous agent: ${agentAddress}`);
      } catch (onChainErr: any) {
        this.logger.warn(`On-chain agent registration warning: ${onChainErr.message}`);
      }
    }

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
   * Ensures the user has at least one active autonomous agent bound to their identity.
   * Uses the user's real provisioned Privy walletAddress with strict zero-fallback policy.
   */
  async ensureDefaultAgentForUser(userId: string): Promise<AgentEntity[]> {
    const existing = await this.getAgentsForUser(userId);
    if (existing.length > 0) {
      return existing;
    }

    // Query authenticated user record to obtain their real Privy EVM wallet
    const userRows = await this.dbService.query<any>(
      'SELECT * FROM "user" WHERE id = ?',
      [userId],
    );

    const walletAddress = userRows.length ? (userRows[0].walletAddress || userRows[0].wallet_address) : null;
    if (!walletAddress) {
      this.logger.log(`User ${userId} does not have a provisioned walletAddress yet; skipping agent auto-binding`);
      return [];
    }

    const safeAddress = process.env.SAFE_ADDRESS || '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
    const guardAddress = process.env.GUARD_ADDRESS || '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
    const agentAddress = walletAddress;

    try {
      const created = await this.bindAgent(userId, {
        agentAddress,
        name: 'Autonomous Treasury Agent',
        purpose: 'Supervised treasury execution and automated operational disbursements',
        safeAddress,
        guardAddress,
        chainId: process.env.CHAIN_ID ? Number(process.env.CHAIN_ID) : 84532,
      });
      return [created];
    } catch (err: any) {
      this.logger.warn(`Failed to auto-bind default agent for user ${userId}: ${err.message}`);
      return [];
    }
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
