import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHash } from 'crypto';
import { getAddress, verifyMessage } from 'ethers';
import { AgentsService } from '../../agents/agents.service';
import { AuthenticatedAgentRequest } from '../interfaces/authenticated-agent-request.interface';

const SIGNATURE_TTL_MS = 120_000;
const TIMESTAMP_TOLERANCE_SECONDS = 60;

/**
 * Authenticates x402 agent requests with their Key Ring-protected wallet key, not a Privy token.
 * The agent signs `chapter2-agent-request\n<METHOD>\n<path+query>\n<timestamp>\n<sha256(body)>`
 * with EIP-191 personal_sign; this guard recovers the signer, checks freshness and replay, and
 * confirms the signer is an ACTIVE agent before attaching it to the request as `request.agent`.
 */
@Injectable()
export class AgentSignatureGuard implements CanActivate {
  private static readonly usedSignatures = new Map<string, number>();

  constructor(private readonly agentsService: AgentsService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedAgentRequest>();

    const agentAddressHeader = this.headerValue(request, 'x-agent-address');
    const timestampHeader = this.headerValue(request, 'x-agent-timestamp');
    const signatureHeader = this.headerValue(request, 'x-agent-signature');

    if (!agentAddressHeader || !timestampHeader || !signatureHeader) {
      throw new UnauthorizedException(
        'Missing X-Agent-Address, X-Agent-Timestamp or X-Agent-Signature header',
      );
    }

    const timestamp = Number(timestampHeader);
    if (!Number.isFinite(timestamp)) {
      throw new UnauthorizedException('X-Agent-Timestamp must be a unix timestamp in seconds');
    }
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (Math.abs(nowSeconds - timestamp) > TIMESTAMP_TOLERANCE_SECONDS) {
      throw new UnauthorizedException('X-Agent-Timestamp is stale or too far in the future');
    }

    this.pruneUsedSignatures();
    if (AgentSignatureGuard.usedSignatures.has(signatureHeader)) {
      throw new UnauthorizedException('Signature has already been used');
    }

    let expectedAddress: string;
    try {
      expectedAddress = getAddress(agentAddressHeader);
    } catch {
      throw new UnauthorizedException('X-Agent-Address is not a valid Ethereum address');
    }

    const bodyHash = createHash('sha256')
      .update(request.rawBody ?? Buffer.alloc(0))
      .digest('hex');
    const path = request.originalUrl || request.url;
    const message = [
      'chapter2-agent-request',
      request.method.toUpperCase(),
      path,
      String(timestamp),
      bodyHash,
    ].join('\n');

    let recoveredAddress: string;
    try {
      recoveredAddress = getAddress(verifyMessage(message, signatureHeader));
    } catch {
      throw new UnauthorizedException('X-Agent-Signature is malformed');
    }

    if (recoveredAddress !== expectedAddress) {
      throw new UnauthorizedException('X-Agent-Signature does not match X-Agent-Address');
    }

    const agent = await this.agentsService.getAgentByAddress(expectedAddress);
    if (!agent || agent.status !== 'ACTIVE') {
      throw new UnauthorizedException('Unknown or inactive agent');
    }

    AgentSignatureGuard.usedSignatures.set(signatureHeader, Date.now() + SIGNATURE_TTL_MS);
    request.agent = agent;
    return true;
  }

  private headerValue(request: AuthenticatedAgentRequest, name: string): string | undefined {
    const value = request.headers[name];
    return Array.isArray(value) ? value[0] : value;
  }

  private pruneUsedSignatures(): void {
    const now = Date.now();
    for (const [signature, expiresAt] of AgentSignatureGuard.usedSignatures.entries()) {
      if (expiresAt <= now) {
        AgentSignatureGuard.usedSignatures.delete(signature);
      }
    }
  }
}
