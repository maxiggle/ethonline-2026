import { describe, expect, it, vi } from 'vitest';

import type { AgentRequestSigner } from './agent-request.js';
import { claimPurchaseRequest, reportProgress, reportResult, type PurchaseRequest } from './purchase-requests.js';

const BASE_URL = 'http://localhost:3001';

const agentAccount: AgentRequestSigner = {
  address: '0x4444444444444444444444444444444444444444',
  signMessage: vi.fn().mockResolvedValue('0xagentsignature'),
};

const samplePurchaseRequest: PurchaseRequest = {
  id: 'pr_1',
  agentAddress: agentAccount.address,
  serviceName: 'Open-Meteo Weather Oracle',
  resourceUrl: `${BASE_URL}/x402/weather`,
  queryParams: { city: 'Lagos' },
  justification: 'brief the morning report',
  amount: '10000',
  status: 'PROCESSING',
  actionId: null,
  decision: null,
  reasons: [],
  transactionHash: null,
  response: null,
  error: null,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
};

describe('claimPurchaseRequest', () => {
  it('returns the claimed request on 200', async () => {
    const agentFetch = vi.fn().mockResolvedValue(new Response(JSON.stringify(samplePurchaseRequest), { status: 200 }));

    const claimed = await claimPurchaseRequest({ baseUrl: BASE_URL, agentAccount, agentFetch });

    expect(claimed).toEqual(samplePurchaseRequest);
    expect(agentFetch).toHaveBeenCalledWith(agentAccount, BASE_URL, 'POST', '/x402/purchase-requests/claim');
  });

  it('returns null when there is nothing to claim (204)', async () => {
    const agentFetch = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));

    const claimed = await claimPurchaseRequest({ baseUrl: BASE_URL, agentAccount, agentFetch });

    expect(claimed).toBeNull();
  });

  it('throws on a non-2xx, non-204 response', async () => {
    const agentFetch = vi.fn().mockResolvedValue(new Response('unauthorized', { status: 401 }));

    await expect(claimPurchaseRequest({ baseUrl: BASE_URL, agentAccount, agentFetch })).rejects.toThrow(
      /POST \/x402\/purchase-requests\/claim failed: 401/,
    );
  });
});

describe('reportProgress', () => {
  it('posts the actionId, decision and reasons', async () => {
    const authorized: PurchaseRequest = { ...samplePurchaseRequest, status: 'AUTHORIZED', actionId: 'act_1', decision: 'ALLOW', reasons: ['ok'] };
    const agentFetch = vi.fn().mockResolvedValue(new Response(JSON.stringify(authorized), { status: 200 }));

    const result = await reportProgress({
      baseUrl: BASE_URL,
      agentAccount,
      agentFetch,
      id: 'pr_1',
      actionId: 'act_1',
      decision: 'ALLOW',
      reasons: ['ok'],
    });

    expect(result).toEqual(authorized);
    expect(agentFetch).toHaveBeenCalledWith(agentAccount, BASE_URL, 'POST', '/x402/purchase-requests/pr_1/progress', {
      actionId: 'act_1',
      decision: 'ALLOW',
      reasons: ['ok'],
    });
  });

  it('throws when the backend rejects the progress report', async () => {
    const agentFetch = vi.fn().mockResolvedValue(new Response('bad state', { status: 400 }));

    await expect(
      reportProgress({ baseUrl: BASE_URL, agentAccount, agentFetch, id: 'pr_1', actionId: 'act_1', decision: 'ALLOW', reasons: [] }),
    ).rejects.toThrow(/POST \/x402\/purchase-requests\/pr_1\/progress failed: 400/);
  });
});

describe('reportResult', () => {
  it('posts a PAID result with the transaction hash and response data', async () => {
    const paid: PurchaseRequest = { ...samplePurchaseRequest, status: 'PAID', transactionHash: '0xabc', response: { temperatureC: 22 } };
    const agentFetch = vi.fn().mockResolvedValue(new Response(JSON.stringify(paid), { status: 200 }));

    const result = await reportResult({
      baseUrl: BASE_URL,
      agentAccount,
      agentFetch,
      id: 'pr_1',
      status: 'PAID',
      actionId: 'act_1',
      transactionHash: '0xabc',
      response: { temperatureC: 22 },
    });

    expect(result).toEqual(paid);
    expect(agentFetch).toHaveBeenCalledWith(agentAccount, BASE_URL, 'POST', '/x402/purchase-requests/pr_1/result', {
      status: 'PAID',
      actionId: 'act_1',
      decision: undefined,
      reasons: undefined,
      transactionHash: '0xabc',
      response: { temperatureC: 22 },
      error: undefined,
    });
  });

  it('posts a FAILED result with just an error message', async () => {
    const failed: PurchaseRequest = { ...samplePurchaseRequest, status: 'FAILED', error: 'resource is not on this backend' };
    const agentFetch = vi.fn().mockResolvedValue(new Response(JSON.stringify(failed), { status: 200 }));

    const result = await reportResult({
      baseUrl: BASE_URL,
      agentAccount,
      agentFetch,
      id: 'pr_1',
      status: 'FAILED',
      error: 'resource is not on this backend',
    });

    expect(result).toEqual(failed);
  });

  it('throws when the backend refuses the result (e.g. terminal-state conflict)', async () => {
    const agentFetch = vi.fn().mockResolvedValue(new Response('already PAID', { status: 409 }));

    await expect(
      reportResult({ baseUrl: BASE_URL, agentAccount, agentFetch, id: 'pr_1', status: 'FAILED', error: 'retry' }),
    ).rejects.toThrow(/POST \/x402\/purchase-requests\/pr_1\/result failed: 409/);
  });
});
