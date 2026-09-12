import { UnauthorizedException, ExecutionContext } from '@nestjs/common';
import { Wallet } from 'ethers';
import { createHash } from 'crypto';
import { AgentSignatureGuard } from './agent-signature.guard';
import { AgentsService } from '../../agents/agents.service';
import { AgentEntity } from '../../agents/interfaces/agent.interface';

describe('AgentSignatureGuard', () => {
  let guard: AgentSignatureGuard;
  let agentsService: { getAgentByAddress: jest.Mock };
  let agentWallet: Wallet;
  let activeAgent: AgentEntity;

  const buildContext = (overrides: Partial<any> = {}): ExecutionContext => {
    const request = {
      headers: {},
      method: 'POST',
      originalUrl: '/x402/payments/authorize',
      url: '/x402/payments/authorize',
      rawBody: Buffer.from(''),
      ...overrides,
    };
    return {
      switchToHttp: () => ({
        getRequest: () => request,
      }),
    } as unknown as ExecutionContext;
  };

  const signRequest = async (
    wallet: Wallet,
    opts: { method?: string; path?: string; timestamp?: number; body?: string } = {},
  ) => {
    const method = opts.method ?? 'POST';
    const path = opts.path ?? '/x402/payments/authorize';
    const timestamp = opts.timestamp ?? Math.floor(Date.now() / 1000);
    const body = opts.body ?? '';
    const bodyHash = createHash('sha256').update(Buffer.from(body)).digest('hex');
    const message = ['chapter2-agent-request', method.toUpperCase(), path, String(timestamp), bodyHash].join(
      '\n',
    );
    const signature = await wallet.signMessage(message);
    return { signature, timestamp, bodyHash, path, method, body };
  };

  beforeEach(() => {
    agentWallet = Wallet.createRandom() as unknown as Wallet;
    activeAgent = {
      id: 'agent_1',
      userId: 'did:privy:owner',
      agentAddress: agentWallet.address,
      name: 'Test Agent',
      purpose: 'testing',
      safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
      chainId: 84532,
      status: 'ACTIVE',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    agentsService = { getAgentByAddress: jest.fn().mockResolvedValue(activeAgent) };
    guard = new AgentSignatureGuard(agentsService as unknown as AgentsService);
  });

  it('accepts a validly signed request and attaches the agent', async () => {
    const { signature, timestamp } = await signRequest(agentWallet);
    const context = buildContext({
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(timestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    const request = context.switchToHttp().getRequest<any>();
    expect(request.agent.agentAddress).toBe(agentWallet.address);
  });

  it('rejects a stale timestamp', async () => {
    const staleTimestamp = Math.floor(Date.now() / 1000) - 3600;
    const { signature } = await signRequest(agentWallet, { timestamp: staleTimestamp });
    const context = buildContext({
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(staleTimestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects a tampered body', async () => {
    const { signature, timestamp } = await signRequest(agentWallet, { body: 'original' });
    const context = buildContext({
      rawBody: Buffer.from('tampered'),
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(timestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects a signature from the wrong signer', async () => {
    const otherWallet = Wallet.createRandom() as unknown as Wallet;
    const { signature, timestamp } = await signRequest(otherWallet);
    const context = buildContext({
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(timestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects a replayed signature', async () => {
    const { signature, timestamp } = await signRequest(agentWallet);
    const context = buildContext({
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(timestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects an unknown agent', async () => {
    agentsService.getAgentByAddress.mockResolvedValue(null);
    const { signature, timestamp } = await signRequest(agentWallet);
    const context = buildContext({
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(timestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects an inactive agent', async () => {
    agentsService.getAgentByAddress.mockResolvedValue({ ...activeAgent, status: 'PAUSED' });
    const { signature, timestamp } = await signRequest(agentWallet);
    const context = buildContext({
      headers: {
        'x-agent-address': agentWallet.address,
        'x-agent-timestamp': String(timestamp),
        'x-agent-signature': signature,
      },
    });

    await expect(guard.canActivate(context)).rejects.toThrow(UnauthorizedException);
  });
});
