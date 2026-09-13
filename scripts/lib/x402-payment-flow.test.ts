import { describe, expect, it, vi } from 'vitest';

import type { PaymentRequirements } from '@x402/core/types';

import type { AgentRequestSigner } from './agent-request.js';
import {
  authorizeAndResolvePaymentSigner,
  type EvmClientSignerLike,
  type PaymentSigningOutcome,
} from './x402-payment-flow.js';

const BASE_URL = 'http://localhost:3001';

const agentAccount: AgentRequestSigner = {
  address: '0x4444444444444444444444444444444444444444',
  signMessage: vi.fn().mockResolvedValue('0xagentsignature'),
};

const agentEvmSigner: EvmClientSignerLike = {
  address: '0x4444444444444444444444444444444444444444',
  signTypedData: vi.fn().mockResolvedValue('0xpaymentsignature'),
};

const paymentRequirements: PaymentRequirements = {
  scheme: 'exact',
  network: 'eip155:84532',
  asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
  amount: '10000',
  payTo: '0x5555555555555555555555555555555555555555',
  maxTimeoutSeconds: 60,
  extra: {},
};

function baseDeps(createLedgerSigner: (actionId: string) => EvmClientSignerLike) {
  return {
    baseUrl: BASE_URL,
    agentAccount,
    resourceUrl: `${BASE_URL}/x402/weather?city=Lagos`,
    paymentRequirements,
    justification: 'test justification',
    agentEvmSigner,
    createLedgerSigner,
  };
}

describe('authorizeAndResolvePaymentSigner', () => {
  it('BLOCK: creates no payment signer and returns the reasons', async () => {
    const agentFetch = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ actionId: 'act_block', decision: 'BLOCK', riskScore: 100, reasons: ['not approved'] }),
        { status: 201 },
      ),
    );
    const createLedgerSigner = vi.fn();

    const outcome: PaymentSigningOutcome = await authorizeAndResolvePaymentSigner({
      ...baseDeps(createLedgerSigner),
      agentFetch,
    });

    expect(outcome).toEqual({ kind: 'BLOCK', actionId: 'act_block', riskScore: 100, reasons: ['not approved'] });
    expect(createLedgerSigner).not.toHaveBeenCalled();
    expect(agentEvmSigner.signTypedData).not.toHaveBeenCalled();
    expect(agentFetch).toHaveBeenCalledWith(agentAccount, BASE_URL, 'POST', '/x402/payments/authorize', {
      resourceUrl: `${BASE_URL}/x402/weather?city=Lagos`,
      paymentRequirements,
      justification: 'test justification',
    });
  });

  it('ALLOW: resolves to a signer that is the agent Key Ring signer', async () => {
    const agentFetch = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ actionId: 'act_allow', decision: 'ALLOW', riskScore: 10, reasons: [] }), {
        status: 201,
      }),
    );
    const createLedgerSigner = vi.fn();

    const outcome = await authorizeAndResolvePaymentSigner({ ...baseDeps(createLedgerSigner), agentFetch });

    expect(outcome.kind).toBe('SIGN');
    if (outcome.kind !== 'SIGN') throw new Error('expected SIGN outcome');
    expect(outcome.decision).toBe('ALLOW');
    expect(outcome.signer).toBe(agentEvmSigner);
    expect(createLedgerSigner).not.toHaveBeenCalled();
  });

  it('ESCALATE: builds a Ledger remote signer bound to the actionId', async () => {
    const agentFetch = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ actionId: 'act_escalate', decision: 'ESCALATE', riskScore: 60, reasons: ['over limit'] }), {
        status: 201,
      }),
    );
    const ledgerSigner: EvmClientSignerLike = {
      address: '0x6666666666666666666666666666666666666666',
      signTypedData: vi.fn().mockResolvedValue('0xledgersignature'),
    };
    const createLedgerSigner = vi.fn().mockReturnValue(ledgerSigner);

    const outcome = await authorizeAndResolvePaymentSigner({ ...baseDeps(createLedgerSigner), agentFetch });

    expect(outcome.kind).toBe('SIGN');
    if (outcome.kind !== 'SIGN') throw new Error('expected SIGN outcome');
    expect(outcome.decision).toBe('ESCALATE');
    expect(outcome.signer).toBe(ledgerSigner);
    expect(createLedgerSigner).toHaveBeenCalledWith('act_escalate');
    expect(agentEvmSigner.signTypedData).not.toHaveBeenCalled();
  });

  it('throws when the authorize call itself fails', async () => {
    const agentFetch = vi.fn().mockResolvedValue(new Response('nope', { status: 401 }));

    await expect(
      authorizeAndResolvePaymentSigner({ ...baseDeps(vi.fn()), agentFetch }),
    ).rejects.toThrow(/POST \/x402\/payments\/authorize failed: 401/);
  });
});
