import { describe, expect, it, vi, beforeEach } from 'vitest';

vi.mock('./lib/purchase-requests.js', () => ({
  reportProgress: vi.fn(),
  reportResult: vi.fn(),
}));

import { reportProgress, reportResult, type PurchaseRequest } from './lib/purchase-requests.js';
import type { AgentRequestSigner } from './lib/agent-request.js';
import type { PayResourceResult } from './lib/x402-payment-flow.js';
import { buildResourcePath, classifyWorkerError, handlePurchaseRequest } from './agent-worker.js';

const BASE_URL = 'http://localhost:3001';

const agentAccount: AgentRequestSigner & { address: `0x${string}`; signTypedData: any } = {
  address: '0x4444444444444444444444444444444444444444',
  signMessage: vi.fn().mockResolvedValue('0xagentsignature'),
  signTypedData: vi.fn().mockResolvedValue('0xpaymentsignature'),
};

const config = {
  approverAddress: '0x6666666666666666666666666666666666666666',
  network: 'eip155:84532',
  usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
};

const baseRequest: PurchaseRequest = {
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

beforeEach(() => {
  vi.mocked(reportProgress).mockReset().mockResolvedValue({ ...baseRequest, status: 'AUTHORIZED' });
  vi.mocked(reportResult).mockReset().mockResolvedValue({ ...baseRequest, status: 'PAID' });
});

describe('buildResourcePath', () => {
  it('builds the path with a URL-encoded query string', () => {
    const path = buildResourcePath(`${BASE_URL}/x402/weather`, BASE_URL, { city: 'Lagos' });
    expect(path).toBe('/x402/weather?city=Lagos');
  });

  it('URL-encodes special characters in query values', () => {
    const path = buildResourcePath(`${BASE_URL}/x402/weather`, BASE_URL, { city: 'San Francisco' });
    expect(path).toBe('/x402/weather?city=San+Francisco');
  });

  it('returns just the path when there are no query params', () => {
    const path = buildResourcePath(`${BASE_URL}/x402/chain-report`, BASE_URL, {});
    expect(path).toBe('/x402/chain-report');
  });

  it('throws when the resourceUrl is not on this backend', () => {
    expect(() => buildResourcePath('https://someone-elses-backend.example/x402/weather', BASE_URL, {})).toThrow(
      /is not on this backend/,
    );
  });
});

describe('classifyWorkerError', () => {
  it('classifies the Ledger rejection message as REJECTED', () => {
    const result = classifyWorkerError(new Error('Escalation for action act_1 was rejected by the human approver'));
    expect(result.status).toBe('REJECTED');
  });

  it('classifies the validBefore timeout message as EXPIRED', () => {
    const result = classifyWorkerError(
      new Error(
        "Timed out waiting for the Ledger approval on action act_1: the payment authorization's validBefore window elapsed before a human signed it. Re-run the scenario.",
      ),
    );
    expect(result.status).toBe('EXPIRED');
  });

  it('classifies anything else as FAILED', () => {
    const result = classifyWorkerError(new Error('Paid retry of https://x failed: 500 boom'));
    expect(result.status).toBe('FAILED');
  });

  it('stringifies non-Error throwables', () => {
    const result = classifyWorkerError('plain string failure');
    expect(result).toEqual({ status: 'FAILED', message: 'plain string failure' });
  });
});

describe('handlePurchaseRequest', () => {
  it('rejects a resourceUrl that is not on this backend and reports FAILED without calling payResource', async () => {
    const payResource = vi.fn();
    const request = { ...baseRequest, resourceUrl: 'https://someone-elses-backend.example/x402/weather' };

    await handlePurchaseRequest(request, { baseUrl: BASE_URL, config, agentAccount, payResource, log: vi.fn() });

    expect(payResource).not.toHaveBeenCalled();
    expect(reportResult).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'pr_1', status: 'FAILED', error: 'resource is not on this backend' }),
    );
  });

  it('reports progress via onAuthorized, then PAID with the transaction hash and response data', async () => {
    const payResource = vi.fn().mockImplementation(async (deps: any) => {
      await deps.onAuthorized({ actionId: 'act_1', decision: 'ALLOW', riskScore: 10, reasons: [] });
      return {
        kind: 'PAID',
        actionId: 'act_1',
        decision: 'ALLOW',
        transactionHash: '0xabc',
        data: { temperatureC: 22 },
      } satisfies PayResourceResult;
    });

    await handlePurchaseRequest(baseRequest, { baseUrl: BASE_URL, config, agentAccount, payResource, log: vi.fn() });

    expect(payResource).toHaveBeenCalledWith(
      expect.objectContaining({ baseUrl: BASE_URL, resourcePath: '/x402/weather?city=Lagos' }),
    );
    expect(reportProgress).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'pr_1', actionId: 'act_1', decision: 'ALLOW', reasons: [] }),
    );
    expect(reportResult).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'pr_1',
        status: 'PAID',
        actionId: 'act_1',
        transactionHash: '0xabc',
        response: { temperatureC: 22 },
      }),
    );
  });

  it('reports BLOCKED with the Guardian reasons', async () => {
    const payResource = vi.fn().mockResolvedValue({
      kind: 'BLOCK',
      actionId: 'act_2',
      riskScore: 100,
      reasons: ['payee not approved'],
    } satisfies PayResourceResult);

    await handlePurchaseRequest(baseRequest, { baseUrl: BASE_URL, config, agentAccount, payResource, log: vi.fn() });

    expect(reportResult).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'pr_1',
        status: 'BLOCKED',
        decision: 'BLOCK',
        reasons: ['payee not approved'],
      }),
    );
  });

  it('reports REJECTED when the Ledger approval is rejected', async () => {
    const payResource = vi
      .fn()
      .mockRejectedValue(new Error('Escalation for action act_3 was rejected by the human approver'));

    await handlePurchaseRequest(baseRequest, { baseUrl: BASE_URL, config, agentAccount, payResource, log: vi.fn() });

    expect(reportResult).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'pr_1', status: 'REJECTED' }),
    );
  });

  it('reports EXPIRED when the validBefore window elapses', async () => {
    const payResource = vi
      .fn()
      .mockRejectedValue(
        new Error("Timed out waiting for the Ledger approval on action act_4: the payment authorization's validBefore window elapsed before a human signed it. Re-run the scenario."),
      );

    await handlePurchaseRequest(baseRequest, { baseUrl: BASE_URL, config, agentAccount, payResource, log: vi.fn() });

    expect(reportResult).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'pr_1', status: 'EXPIRED' }),
    );
  });

  it('reports FAILED for any other thrown error', async () => {
    const payResource = vi.fn().mockRejectedValue(new Error('Paid retry of https://x failed: 500 boom'));

    await handlePurchaseRequest(baseRequest, { baseUrl: BASE_URL, config, agentAccount, payResource, log: vi.fn() });

    expect(reportResult).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'pr_1', status: 'FAILED', error: 'Paid retry of https://x failed: 500 boom' }),
    );
  });
});
