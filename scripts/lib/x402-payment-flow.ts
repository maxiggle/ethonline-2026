import { x402Client } from '@x402/core/client';
import { x402HTTPClient } from '@x402/core/http';
import type { PaymentRequired, PaymentRequirements } from '@x402/core/types';
import { registerExactEvmScheme } from '@x402/evm/exact/client';

import { signedAgentFetch, type AgentRequestSigner } from './agent-request.js';
import type { EvmTypedData } from './ledger-remote-signer.js';

export type GuardianDecisionType = 'ALLOW' | 'ESCALATE' | 'BLOCK';

export interface AuthorizePaymentResponse {
  actionId: string;
  decision: GuardianDecisionType;
  riskScore: number;
  reasons: string[];
}

/** The `ClientEvmSigner` surface the x402 EVM scheme needs: an address plus EIP-712 signing. */
export interface EvmClientSignerLike {
  readonly address: `0x${string}`;
  signTypedData(typedData: EvmTypedData): Promise<`0x${string}`>;
}

export type PaymentSigningOutcome =
  | { kind: 'BLOCK'; actionId: string; riskScore: number; reasons: string[] }
  | { kind: 'SIGN'; actionId: string; decision: 'ALLOW' | 'ESCALATE'; riskScore: number; signer: EvmClientSignerLike };

/**
 * Picks the payment requirement the ticket's flow always pays with: the accept on the configured
 * network whose asset is the Guardian-approved USDC contract, from `GET /x402/approvals/config`.
 */
export function selectPaymentRequirement(
  paymentRequired: PaymentRequired,
  network: string,
  usdcAddress: string,
): PaymentRequirements {
  const normalizedUsdc = usdcAddress.toLowerCase();
  const match = paymentRequired.accepts.find(
    (accept) => accept.network === network && accept.asset.toLowerCase() === normalizedUsdc,
  );
  if (!match) {
    throw new Error(
      `The 402 response for ${paymentRequired.resource.url} has no accept for network ${network} ` +
        `and USDC asset ${usdcAddress}`,
    );
  }
  return match;
}

export interface AuthorizePaymentDeps {
  baseUrl: string;
  agentAccount: AgentRequestSigner;
  agentFetch?: typeof signedAgentFetch;
  resourceUrl: string;
  paymentRequirements: PaymentRequirements;
  justification: string;
}

/** Asks the Guardian to authorize one x402 payment. Every call creates its own `TreasuryAction`. */
export async function authorizePayment(deps: AuthorizePaymentDeps): Promise<AuthorizePaymentResponse> {
  const agentFetch = deps.agentFetch ?? signedAgentFetch;
  const response = await agentFetch(deps.agentAccount, deps.baseUrl, 'POST', '/x402/payments/authorize', {
    resourceUrl: deps.resourceUrl,
    paymentRequirements: deps.paymentRequirements,
    justification: deps.justification,
  });
  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`POST /x402/payments/authorize failed: ${response.status} ${errorBody}`);
  }
  return (await response.json()) as AuthorizePaymentResponse;
}

export interface ResolvePaymentSignerDeps {
  authorization: AuthorizePaymentResponse;
  /** The Key Ring agent account, used to sign directly when the decision is ALLOW. */
  agentEvmSigner: EvmClientSignerLike;
  /** Builds a Ledger remote signer bound to this action, used only when the decision is ESCALATE. */
  createLedgerSigner: (actionId: string) => EvmClientSignerLike;
}

/**
 * Turns a Guardian decision into either a refusal (BLOCK, no signer touched) or a signer to build
 * the payment payload with (ALLOW: the agent's own Key Ring wallet; ESCALATE: a Ledger remote
 * signer that will not resolve until a human approves). Creating the signer never signs anything
 * by itself — the x402 EVM scheme calls `signTypedData` exactly once, when it builds the payload.
 */
export function resolvePaymentSigner(deps: ResolvePaymentSignerDeps): PaymentSigningOutcome {
  const { authorization } = deps;
  if (authorization.decision === 'BLOCK') {
    return {
      kind: 'BLOCK',
      actionId: authorization.actionId,
      riskScore: authorization.riskScore,
      reasons: authorization.reasons,
    };
  }
  if (authorization.decision === 'ESCALATE') {
    return {
      kind: 'SIGN',
      actionId: authorization.actionId,
      decision: 'ESCALATE',
      riskScore: authorization.riskScore,
      signer: deps.createLedgerSigner(authorization.actionId),
    };
  }
  return {
    kind: 'SIGN',
    actionId: authorization.actionId,
    decision: 'ALLOW',
    riskScore: authorization.riskScore,
    signer: deps.agentEvmSigner,
  };
}

export type AuthorizeAndResolveSignerDeps = AuthorizePaymentDeps &
  Pick<ResolvePaymentSignerDeps, 'agentEvmSigner' | 'createLedgerSigner'>;

/** Combines {@link authorizePayment} and {@link resolvePaymentSigner} for the common call site. */
export async function authorizeAndResolvePaymentSigner(
  deps: AuthorizeAndResolveSignerDeps,
): Promise<PaymentSigningOutcome> {
  const authorization = await authorizePayment(deps);
  return resolvePaymentSigner({
    authorization,
    agentEvmSigner: deps.agentEvmSigner,
    createLedgerSigner: deps.createLedgerSigner,
  });
}

export interface SettlePaymentDeps {
  baseUrl: string;
  agentAccount: AgentRequestSigner;
  agentFetch?: typeof signedAgentFetch;
  actionId: string;
  transactionHash: string;
}

/** Reports a completed settlement back to the Guardian so the `TreasuryAction` closes out. */
export async function settlePayment(deps: SettlePaymentDeps): Promise<{ actionId: string; status: string }> {
  const agentFetch = deps.agentFetch ?? signedAgentFetch;
  const response = await agentFetch(
    deps.agentAccount,
    deps.baseUrl,
    'POST',
    `/x402/payments/${deps.actionId}/settlement`,
    { transactionHash: deps.transactionHash },
  );
  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`POST /x402/payments/${deps.actionId}/settlement failed: ${response.status} ${errorBody}`);
  }
  return (await response.json()) as { actionId: string; status: string };
}

export interface PayResourceDeps {
  baseUrl: string;
  network: string;
  usdcAddress: string;
  resourcePath: string;
  justification: string;
  agentAccount: AgentRequestSigner;
  agentEvmSigner: EvmClientSignerLike;
  createLedgerSigner: (actionId: string) => EvmClientSignerLike;
  fetchImpl?: typeof fetch;
  agentFetch?: typeof signedAgentFetch;
  onWaitingForApproval?: () => void;
  /** Called with the Guardian's authorization response right after `authorizePayment`, before any signer is touched. */
  onAuthorized?: (authorization: AuthorizePaymentResponse) => Promise<void>;
}

export type PayResourceResult =
  | { kind: 'BLOCK'; actionId: string; riskScore: number; reasons: string[] }
  | {
      kind: 'PAID';
      actionId: string;
      decision: 'ALLOW' | 'ESCALATE';
      transactionHash: string;
      data: unknown;
    };

/**
 * Pays one x402 v2 resource end to end: fetch the 402, ask the Guardian, sign with the right
 * signer for the decision, retry with the payment header, and report the settlement back.
 * Exactly one Guardian authorization and, when not BLOCKed, exactly one payment signature happen
 * per call — the payment payload is built manually with the core client instead of
 * `wrapFetchWithPayment`, so no automatic retry can duplicate either step.
 */
export async function payX402Resource(deps: PayResourceDeps): Promise<PayResourceResult> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const resourceUrl = `${deps.baseUrl}${deps.resourcePath}`;

  const initialResponse = await fetchImpl(resourceUrl);
  if (initialResponse.status !== 402) {
    throw new Error(
      `Expected ${resourceUrl} to return 402 Payment Required, got ${initialResponse.status}`,
    );
  }

  const decodingClient = new x402HTTPClient(new x402Client());
  let initialBody: unknown;
  try {
    initialBody = await initialResponse.clone().json();
  } catch {
    initialBody = undefined;
  }
  const paymentRequired = decodingClient.getPaymentRequiredResponse(
    (name) => initialResponse.headers.get(name),
    initialBody,
  );

  const paymentRequirements = selectPaymentRequirement(paymentRequired, deps.network, deps.usdcAddress);

  const authorization = await authorizePayment({
    baseUrl: deps.baseUrl,
    agentAccount: deps.agentAccount,
    agentFetch: deps.agentFetch,
    resourceUrl,
    paymentRequirements,
    justification: deps.justification,
  });

  await deps.onAuthorized?.(authorization);

  const outcome = resolvePaymentSigner({
    authorization,
    agentEvmSigner: deps.agentEvmSigner,
    createLedgerSigner: deps.createLedgerSigner,
  });

  if (outcome.kind === 'BLOCK') {
    return { kind: 'BLOCK', actionId: outcome.actionId, riskScore: outcome.riskScore, reasons: outcome.reasons };
  }

  if (outcome.decision === 'ESCALATE') {
    deps.onWaitingForApproval?.();
  }

  const paymentClient = createGuardianCappedPaymentClient(paymentRequirements, outcome.signer, deps.network);
  const paymentHttpClient = new x402HTTPClient(paymentClient);

  const paymentPayload = await paymentHttpClient.createPaymentPayload(paymentRequired);
  const paymentHeaders = paymentHttpClient.encodePaymentSignatureHeader(paymentPayload);

  const paidResponse = await fetchImpl(resourceUrl, { headers: paymentHeaders });
  if (!paidResponse.ok) {
    const errorBody = await paidResponse.text();
    throw new Error(`Paid retry of ${resourceUrl} failed: ${paidResponse.status} ${errorBody}`);
  }

  const settleResponse = paymentHttpClient.getPaymentSettleResponse((name) => paidResponse.headers.get(name));
  if (!settleResponse.success || !settleResponse.transaction) {
    throw new Error(`Facilitator did not report a successful settlement for ${resourceUrl}`);
  }

  const data = await paidResponse.json();

  await settlePayment({
    baseUrl: deps.baseUrl,
    agentAccount: deps.agentAccount,
    agentFetch: deps.agentFetch,
    actionId: outcome.actionId,
    transactionHash: settleResponse.transaction,
  });

  return {
    kind: 'PAID',
    actionId: outcome.actionId,
    decision: outcome.decision,
    transactionHash: settleResponse.transaction,
    data,
  };
}

/**
 * Builds the x402 client that signs one Guardian-authorized payment.
 *
 * The SDK's default spend control caps every payment at $1, which would reject escalated payments
 * before the Ledger is asked to sign. The Guardian has already authorized this exact requirement, so
 * the SDK cap is pinned to that requirement's asset and atomic amount: anything larger is still refused.
 */
export function createGuardianCappedPaymentClient(
  paymentRequirements: PaymentRequirements,
  signer: EvmClientSignerLike,
  network: string,
): x402Client {
  const paymentClient = new x402Client(
    (_version, requirements) =>
      requirements.find(
        (candidate) =>
          candidate.network === paymentRequirements.network &&
          candidate.asset.toLowerCase() === paymentRequirements.asset.toLowerCase(),
      ) ?? requirements[0],
  );
  paymentClient.setSpendControls({
    allowedAssets: [
      {
        network: paymentRequirements.network,
        asset: paymentRequirements.asset,
        maxAmountPerPayment: paymentRequirements.amount,
      },
    ],
  });
  registerExactEvmScheme(paymentClient, { signer, networks: [network as `${string}:${string}`] });
  return paymentClient;
}
