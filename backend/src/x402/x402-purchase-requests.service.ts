import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import { getAddress } from 'ethers';
import { DatabaseService } from '../database/database.service';
import { X402PurchaseRequestRow } from '../database/database.interface';
import { AgentsService } from '../agents/agents.service';
import { AgentEntity } from '../agents/interfaces/agent.interface';
import { ActionStoreService } from '../actions/action-store.service';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { VendorService } from '../vendor/vendor.service';
import { CreatePurchaseRequestDto } from './dto/create-purchase-request.dto';
import { ReportPurchaseRequestProgressDto } from './dto/report-purchase-request-progress.dto';
import { ReportPurchaseRequestResultDto } from './dto/report-purchase-request-result.dto';
import { PURCHASE_REQUEST_TERMINAL_STATUSES, PurchaseRequest } from './interfaces/purchase-request.interface';

const MAX_QUERY_PARAM_VALUE_LENGTH = 100;
const MAX_JUSTIFICATION_LENGTH = 280;
const MAX_RESPONSE_BYTES = 32 * 1024;

@Injectable()
export class X402PurchaseRequestsService {
  /** Per-agent-address promise chain: serializes claims so two workers can never claim the same row. */
  private readonly claimLocks = new Map<string, Promise<unknown>>();

  constructor(
    private readonly databaseService: DatabaseService,
    private readonly agentsService: AgentsService,
    private readonly actionStore: ActionStoreService,
    @Inject(forwardRef(() => VendorService)) private readonly vendorService: VendorService,
  ) {}

  async createRequest(userId: string, dto: CreatePurchaseRequestDto): Promise<PurchaseRequest> {
    await this.agentsService.assertAgentOwnership(userId, dto.agentAddress);
    const agentAddress = getAddress(dto.agentAddress);

    const catalogEntry = this.vendorService.getBazaarCatalog().find((entry) => entry.resource === dto.resourceUrl);
    if (!catalogEntry) {
      throw new BadRequestException(`Unknown x402 resource: '${dto.resourceUrl}'`);
    }

    const allowedQueryParams = catalogEntry.extensions.bazaar.info.input.queryParams || {};
    const queryParams = this.validateQueryParams(dto.queryParams, allowedQueryParams, dto.resourceUrl);

    if (!dto.justification || dto.justification.trim().length === 0) {
      throw new BadRequestException('justification must be non-empty');
    }
    if (dto.justification.length > MAX_JUSTIFICATION_LENGTH) {
      throw new BadRequestException(`justification must be at most ${MAX_JUSTIFICATION_LENGTH} characters`);
    }

    const now = new Date().toISOString();
    const id = `pr_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const serviceName = catalogEntry.extensions.bazaar.info.serviceName;
    const amount = catalogEntry.accepts[0].amount;

    await this.databaseService.run(
      `INSERT INTO x402_purchase_requests (
        id, user_id, agent_address, service_name, resource_url, query_params, justification,
        amount, status, action_id, decision, reasons, transaction_hash, response, error,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        userId,
        agentAddress,
        serviceName,
        dto.resourceUrl,
        JSON.stringify(queryParams),
        dto.justification,
        amount,
        'QUEUED',
        null,
        null,
        JSON.stringify([]),
        null,
        null,
        null,
        now,
        now,
      ],
    );

    return this.getOwnedRowOrThrow(userId, id);
  }

  async listForUser(userId: string): Promise<PurchaseRequest[]> {
    const rows = await this.databaseService.query<X402PurchaseRequestRow>(
      'SELECT * FROM x402_purchase_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 50',
      [userId],
    );
    return rows.map((row) => this.mapRow(row));
  }

  async getForUser(userId: string, id: string): Promise<PurchaseRequest> {
    return this.getOwnedRowOrThrow(userId, id);
  }

  /**
   * Atomically claims the oldest QUEUED request for this agent. Claims for the same agent address
   * are serialized through an in-memory promise chain, so two concurrent workers authenticated as
   * the same agent can never both claim the same request; the conditional `WHERE status = 'QUEUED'`
   * update is a second line of defense against any other writer.
   */
  async claim(agent: AgentEntity): Promise<PurchaseRequest | null> {
    const agentAddress = getAddress(agent.agentAddress);
    const previous = this.claimLocks.get(agentAddress) ?? Promise.resolve();
    const next = previous.then(
      () => this.claimOldestQueued(agentAddress),
      () => this.claimOldestQueued(agentAddress),
    );
    this.claimLocks.set(
      agentAddress,
      next.catch(() => undefined),
    );
    return next;
  }

  async reportProgress(
    agent: AgentEntity,
    id: string,
    dto: ReportPurchaseRequestProgressDto,
  ): Promise<PurchaseRequest> {
    const row = await this.getRowOrThrow(id);
    this.assertClaimingAgent(agent, row);

    if (row.status !== 'PROCESSING') {
      throw new BadRequestException(`Purchase request ${id} is not PROCESSING (current status: ${row.status})`);
    }

    const action = this.actionStore.getAction(dto.actionId);
    if (!action || !this.isSameAddress(action.agentAddress, agent.agentAddress)) {
      throw new BadRequestException(`Action ${dto.actionId} does not belong to agent ${agent.agentAddress}`);
    }
    if (!this.actionAuthorizesResource(action.justification, row.resource_url)) {
      throw new BadRequestException(`Action ${dto.actionId} does not authorize resource ${row.resource_url}`);
    }

    const now = new Date().toISOString();
    await this.databaseService.run(
      `UPDATE x402_purchase_requests SET status = ?, action_id = ?, decision = ?, reasons = ?, updated_at = ? WHERE id = ?`,
      ['AUTHORIZED', dto.actionId, dto.decision, JSON.stringify(dto.reasons ?? []), now, id],
    );

    return this.mapRow(await this.getRowOrThrow(id));
  }

  async reportResult(agent: AgentEntity, id: string, dto: ReportPurchaseRequestResultDto): Promise<PurchaseRequest> {
    const row = await this.getRowOrThrow(id);
    this.assertClaimingAgent(agent, row);

    if (PURCHASE_REQUEST_TERMINAL_STATUSES.includes(row.status)) {
      throw new ConflictException(`Purchase request ${id} is already ${row.status}`);
    }
    if (row.status !== 'PROCESSING' && row.status !== 'AUTHORIZED') {
      throw new BadRequestException(
        `Purchase request ${id} must be PROCESSING or AUTHORIZED to report a result (current status: ${row.status})`,
      );
    }

    if (dto.status === 'PAID') {
      this.assertPaidResultIsBackedByAnExecutedAction(agent, dto);
    }
    if (dto.status === 'BLOCKED' && dto.decision !== 'BLOCK') {
      throw new BadRequestException("A BLOCKED result requires decision === 'BLOCK'");
    }

    const responseJson = this.serializeResponse(dto.response);

    const now = new Date().toISOString();
    await this.databaseService.run(
      `UPDATE x402_purchase_requests SET status = ?, action_id = ?, decision = ?, reasons = ?, transaction_hash = ?, response = ?, error = ?, updated_at = ? WHERE id = ?`,
      [
        dto.status,
        dto.actionId ?? row.action_id,
        dto.decision ?? row.decision,
        dto.reasons ? JSON.stringify(dto.reasons) : row.reasons,
        dto.transactionHash ? dto.transactionHash.toLowerCase() : row.transaction_hash,
        responseJson,
        dto.error ?? null,
        now,
        id,
      ],
    );

    return this.mapRow(await this.getRowOrThrow(id));
  }

  private async claimOldestQueued(agentAddress: string): Promise<PurchaseRequest | null> {
    const rows = await this.databaseService.query<X402PurchaseRequestRow>(
      'SELECT * FROM x402_purchase_requests WHERE agent_address = ? ORDER BY created_at ASC',
      [agentAddress],
    );
    const oldestQueued = rows.find((row) => row.status === 'QUEUED');
    if (!oldestQueued) {
      return null;
    }

    const now = new Date().toISOString();
    const result = await this.databaseService.run(
      `UPDATE x402_purchase_requests SET status = ?, updated_at = ? WHERE id = ? AND status = 'QUEUED'`,
      ['PROCESSING', now, oldestQueued.id],
    );
    if (result.changes === 0) {
      return null;
    }

    return this.mapRow(await this.getRowOrThrow(oldestQueued.id));
  }

  /**
   * `PAID` is accepted only when backend state proves it: an `actionId` owned by the reporting
   * agent whose `TreasuryAction` the Guardian has marked `EXECUTED`, with a `txHash` equal
   * (case-insensitively) to the reported `transactionHash`. The client's claim alone is never
   * trusted.
   */
  private assertPaidResultIsBackedByAnExecutedAction(agent: AgentEntity, dto: ReportPurchaseRequestResultDto): void {
    if (!dto.actionId || !dto.transactionHash) {
      throw new BadRequestException('actionId and transactionHash are required to report a PAID result');
    }
    const action = this.actionStore.getAction(dto.actionId);
    const isExecutedByThisAgent =
      !!action &&
      this.isSameAddress(action.agentAddress, agent.agentAddress) &&
      action.status === TreasuryActionStatus.EXECUTED &&
      !!action.txHash &&
      action.txHash.toLowerCase() === dto.transactionHash.toLowerCase();

    if (!isExecutedByThisAgent) {
      throw new BadRequestException(
        `Action ${dto.actionId} is not an EXECUTED payment owned by ${agent.agentAddress} matching transaction hash ${dto.transactionHash}`,
      );
    }
  }

  private serializeResponse(response: Record<string, unknown> | undefined): string | null {
    if (response === undefined) {
      return null;
    }
    const serialized = JSON.stringify(response);
    if (Buffer.byteLength(serialized, 'utf8') > MAX_RESPONSE_BYTES) {
      throw new BadRequestException(`response must be at most ${MAX_RESPONSE_BYTES / 1024} KB of JSON`);
    }
    return serialized;
  }

  private validateQueryParams(
    queryParams: Record<string, unknown> | undefined,
    allowedQueryParams: Record<string, unknown>,
    resourceUrl: string,
  ): Record<string, string> {
    const result: Record<string, string> = {};
    for (const [key, value] of Object.entries(queryParams ?? {})) {
      if (!(key in allowedQueryParams)) {
        throw new BadRequestException(`Unknown query parameter '${key}' for resource '${resourceUrl}'`);
      }
      if (typeof value !== 'string' || value.length === 0) {
        throw new BadRequestException(`queryParams.${key} must be a non-empty string`);
      }
      if (value.length > MAX_QUERY_PARAM_VALUE_LENGTH) {
        throw new BadRequestException(
          `queryParams.${key} must be at most ${MAX_QUERY_PARAM_VALUE_LENGTH} characters`,
        );
      }
      result[key] = value;
    }
    return result;
  }

  /**
   * `AgentSignatureGuard` authorizes the request as one specific agent; the purchase request's
   * `agent_address` names the only agent allowed to claim, progress or resolve it.
   */
  private assertClaimingAgent(agent: AgentEntity, row: X402PurchaseRequestRow): void {
    if (!this.isSameAddress(row.agent_address, agent.agentAddress)) {
      throw new ForbiddenException(`Purchase request ${row.id} does not belong to agent ${agent.agentAddress}`);
    }
  }

  /**
   * The authorized `TreasuryAction`'s justification is `x402: <resourceUrl-with-query> | ...`.
   * A prefix match against the purchase request's (query-string-free) resourceUrl is correct
   * because the worker pays the resource with its query string appended.
   */
  private actionAuthorizesResource(justification: string, resourceUrl: string): boolean {
    const match = justification.match(/^x402: (\S+)/);
    return !!match && match[1].startsWith(resourceUrl);
  }

  private isSameAddress(a: string, b: string): boolean {
    try {
      return getAddress(a) === getAddress(b);
    } catch {
      return a.toLowerCase() === b.toLowerCase();
    }
  }

  private async getRowOrThrow(id: string): Promise<X402PurchaseRequestRow> {
    const row = await this.databaseService.getOne<X402PurchaseRequestRow>(
      'SELECT * FROM x402_purchase_requests WHERE id = ?',
      [id],
    );
    if (!row) {
      throw new NotFoundException(`Purchase request ${id} not found`);
    }
    return row;
  }

  private async getOwnedRowOrThrow(userId: string, id: string): Promise<PurchaseRequest> {
    const row = await this.databaseService.getOne<X402PurchaseRequestRow>(
      'SELECT * FROM x402_purchase_requests WHERE id = ?',
      [id],
    );
    if (!row || row.user_id !== userId) {
      throw new NotFoundException(`Purchase request ${id} not found`);
    }
    return this.mapRow(row);
  }

  private mapRow(row: X402PurchaseRequestRow): PurchaseRequest {
    return {
      id: row.id,
      agentAddress: row.agent_address,
      serviceName: row.service_name,
      resourceUrl: row.resource_url,
      queryParams: JSON.parse(row.query_params || '{}'),
      justification: row.justification,
      amount: row.amount,
      status: row.status,
      actionId: row.action_id,
      decision: row.decision as PurchaseRequest['decision'],
      reasons: JSON.parse(row.reasons || '[]'),
      transactionHash: row.transaction_hash,
      response: row.response ? JSON.parse(row.response) : null,
      error: row.error,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
