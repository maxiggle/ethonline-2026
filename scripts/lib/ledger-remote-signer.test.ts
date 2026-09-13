import { describe, expect, it, vi } from 'vitest';

import { createLedgerRemoteSigner, type EvmTypedData } from './ledger-remote-signer.js';
import type { AgentRequestSigner } from './agent-request.js';

const APPROVER_ADDRESS = '0x1111111111111111111111111111111111111111' as const;
const ACTION_ID = 'action_escalate_1';
const BASE_URL = 'http://localhost:3001';

const agentAccount: AgentRequestSigner = {
  address: '0x2222222222222222222222222222222222222222',
  signMessage: vi.fn().mockResolvedValue('0xsignature'),
};

function buildTypedData(validBeforeSeconds: number): EvmTypedData {
  return {
    domain: { name: 'USDC', version: '2', chainId: 84532, verifyingContract: '0x036CbD53842c5426634e7929541eC2318f3dCF7e' },
    types: { TransferWithAuthorization: [{ name: 'from', type: 'address' }] },
    primaryType: 'TransferWithAuthorization',
    message: {
      from: APPROVER_ADDRESS,
      to: '0x3333333333333333333333333333333333333333',
      value: 2_000_000n,
      validAfter: 0n,
      validBefore: BigInt(validBeforeSeconds),
      nonce: '0xdeadbeef',
    },
  };
}

describe('createLedgerRemoteSigner', () => {
  it('posts the typed data, polls, and returns the signature once SIGNED', async () => {
    const nowMs = 1_700_000_000_000;
    const nowSeconds = Math.floor(nowMs / 1000);
    const typedData = buildTypedData(nowSeconds + 120);

    const agentFetch = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ actionId: ACTION_ID, status: 'AWAITING_SIGNATURE' }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ escalationStatus: 'PENDING' }), { status: 200 }))
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ escalationStatus: 'SIGNED', signature: '0xledgersignature' }), { status: 200 }),
      );
    const sleep = vi.fn().mockResolvedValue(undefined);
    const onWaiting = vi.fn();

    const signer = createLedgerRemoteSigner({
      approverAddress: APPROVER_ADDRESS,
      actionId: ACTION_ID,
      agentAccount,
      baseUrl: BASE_URL,
      agentFetch,
      sleep,
      now: () => nowMs,
      onWaiting,
    });

    expect(signer.address).toBe(APPROVER_ADDRESS);

    const signature = await signer.signTypedData(typedData);

    expect(signature).toBe('0xledgersignature');
    expect(onWaiting).toHaveBeenCalledTimes(1);

    expect(agentFetch).toHaveBeenNthCalledWith(
      1,
      agentAccount,
      BASE_URL,
      'POST',
      `/x402/payments/${ACTION_ID}/escalation`,
      { typedData: expect.objectContaining({ message: expect.objectContaining({ value: '2000000' }) }) },
    );

    expect(agentFetch).toHaveBeenNthCalledWith(2, agentAccount, BASE_URL, 'GET', `/x402/payments/${ACTION_ID}`);
    expect(agentFetch).toHaveBeenNthCalledWith(3, agentAccount, BASE_URL, 'GET', `/x402/payments/${ACTION_ID}`);
    expect(sleep).toHaveBeenCalledTimes(2);
  });

  it('throws when the escalation is REJECTED', async () => {
    const nowMs = 1_700_000_000_000;
    const nowSeconds = Math.floor(nowMs / 1000);
    const typedData = buildTypedData(nowSeconds + 120);

    const agentFetch = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ status: 'AWAITING_SIGNATURE' }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ escalationStatus: 'REJECTED' }), { status: 200 }));

    const signer = createLedgerRemoteSigner({
      approverAddress: APPROVER_ADDRESS,
      actionId: ACTION_ID,
      agentAccount,
      baseUrl: BASE_URL,
      agentFetch,
      sleep: vi.fn().mockResolvedValue(undefined),
      now: () => nowMs,
    });

    await expect(signer.signTypedData(typedData)).rejects.toThrow(/rejected by the human approver/);
  });

  it('throws a clear timeout error bounded by validBefore, without polling forever', async () => {
    const nowMs = 1_700_000_000_000;
    const nowSeconds = Math.floor(nowMs / 1000);
    const typedData = buildTypedData(nowSeconds + 5);

    const agentFetch = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ status: 'AWAITING_SIGNATURE' }), { status: 200 }))
      .mockImplementation(async () => new Response(JSON.stringify({ escalationStatus: 'PENDING' }), { status: 200 }));

    let elapsedMs = 0;
    const sleep = vi.fn().mockImplementation(async (ms: number) => {
      elapsedMs += ms;
    });

    const signer = createLedgerRemoteSigner({
      approverAddress: APPROVER_ADDRESS,
      actionId: ACTION_ID,
      agentAccount,
      baseUrl: BASE_URL,
      agentFetch,
      sleep,
      now: () => nowMs + elapsedMs,
      pollIntervalMs: 3_000,
      maxWaitMs: 10 * 60 * 1000,
    });

    await expect(signer.signTypedData(typedData)).rejects.toThrow(/Timed out waiting for the Ledger approval/);

    expect(elapsedMs).toBeLessThan(10 * 60 * 1000);
  });
});
