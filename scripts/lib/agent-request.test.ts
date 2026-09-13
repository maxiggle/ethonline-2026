import { createHash } from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import { privateKeyToAccount } from 'viem/accounts';
import { recoverMessageAddress } from 'viem';

import { signedAgentFetch } from './agent-request.js';

const TEST_PRIVATE_KEY = '0x305d73521f6f7cac48c5abfcfe501e9068bcfff3ce73f0fcab1439cd88cea301';

function buildExpectedMessage(method: string, path: string, timestamp: number, body: string): string {
  const bodyHash = createHash('sha256').update(Buffer.from(body, 'utf8')).digest('hex');
  return ['chapter2-agent-request', method.toUpperCase(), path, String(timestamp), bodyHash].join('\n');
}

describe('signedAgentFetch', () => {
  it('signs the exact backend guard message format for a GET with no body', async () => {
    const account = privateKeyToAccount(TEST_PRIVATE_KEY);
    const fetchImpl = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));
    const fixedNowMs = 1_700_000_000_000;

    await signedAgentFetch(account, 'http://localhost:3001', 'GET', '/x402/payments/act_1', undefined, {
      fetchImpl,
      now: () => fixedNowMs,
    });

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = fetchImpl.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('http://localhost:3001/x402/payments/act_1');
    expect(init.method).toBe('GET');
    expect(init.body).toBeUndefined();

    const headers = init.headers as Record<string, string>;
    const timestamp = Number(headers['X-Agent-Timestamp']);
    expect(timestamp).toBe(Math.floor(fixedNowMs / 1000));
    expect(headers['X-Agent-Address']).toBe(account.address);

    const expectedMessage = buildExpectedMessage('GET', '/x402/payments/act_1', timestamp, '');
    const recovered = await recoverMessageAddress({
      message: expectedMessage,
      signature: headers['X-Agent-Signature'] as `0x${string}`,
    });
    expect(recovered).toBe(account.address);
  });

  it('includes the query string in the signed path and hashes the exact JSON body sent', async () => {
    const account = privateKeyToAccount(TEST_PRIVATE_KEY);
    const fetchImpl = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));
    const fixedNowMs = 1_700_000_050_000;
    const body = { resourceUrl: 'http://localhost:3001/x402/weather?city=Lagos', justification: 'demo' };

    await signedAgentFetch(
      account,
      'http://localhost:3001',
      'post',
      '/x402/payments/authorize?debug=true',
      body,
      { fetchImpl, now: () => fixedNowMs },
    );

    const [, init] = fetchImpl.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(init.method).toBe('POST');
    expect(headers['Content-Type']).toBe('application/json');
    expect(init.body).toBe(JSON.stringify(body));

    const timestamp = Number(headers['X-Agent-Timestamp']);
    const expectedMessage = buildExpectedMessage(
      'POST',
      '/x402/payments/authorize?debug=true',
      timestamp,
      JSON.stringify(body),
    );

    const recovered = await recoverMessageAddress({
      message: expectedMessage,
      signature: headers['X-Agent-Signature'] as `0x${string}`,
    });
    expect(recovered).toBe(account.address);
  });

  it('hashes the empty buffer, not the string "undefined", when there is no body', async () => {
    const account = privateKeyToAccount(TEST_PRIVATE_KEY);
    const fetchImpl = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));

    await signedAgentFetch(account, 'http://localhost:3001', 'GET', '/x402/approvals/config', undefined, {
      fetchImpl,
      now: () => 1_700_000_100_000,
    });

    const [, init] = fetchImpl.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    const emptyBodyHash = createHash('sha256').update(Buffer.alloc(0)).digest('hex');
    const timestamp = Number(headers['X-Agent-Timestamp']);
    const message = ['chapter2-agent-request', 'GET', '/x402/approvals/config', String(timestamp), emptyBodyHash].join(
      '\n',
    );

    const recovered = await recoverMessageAddress({
      message,
      signature: headers['X-Agent-Signature'] as `0x${string}`,
    });
    expect(recovered).toBe(account.address);
  });
});
