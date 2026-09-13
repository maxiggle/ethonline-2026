import { signedAgentFetch, type AgentRequestSigner } from './agent-request.js';
import type { GuardianDecisionType } from './x402-payment-flow.js';

export type PurchaseRequestStatus =
  | 'QUEUED'
  | 'PROCESSING'
  | 'AUTHORIZED'
  | 'PAID'
  | 'BLOCKED'
  | 'REJECTED'
  | 'EXPIRED'
  | 'FAILED';

/** The purchase-request object shape fixed by TICKET-X402-004's API contract. */
export interface PurchaseRequest {
  id: string;
  agentAddress: string;
  serviceName: string;
  resourceUrl: string;
  queryParams: Record<string, string>;
  justification: string;
  amount: string;
  status: PurchaseRequestStatus;
  actionId: string | null;
  decision: GuardianDecisionType | null;
  reasons: string[];
  transactionHash: string | null;
  response: unknown;
  error: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PurchaseRequestsDeps {
  baseUrl: string;
  agentAccount: AgentRequestSigner;
  agentFetch?: typeof signedAgentFetch;
}

/** Claims the oldest QUEUED purchase request for this agent, or `null` when there is nothing to claim. */
export async function claimPurchaseRequest(deps: PurchaseRequestsDeps): Promise<PurchaseRequest | null> {
  const agentFetch = deps.agentFetch ?? signedAgentFetch;
  const response = await agentFetch(deps.agentAccount, deps.baseUrl, 'POST', '/x402/purchase-requests/claim');
  if (response.status === 204) {
    return null;
  }
  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`POST /x402/purchase-requests/claim failed: ${response.status} ${errorBody}`);
  }
  return (await response.json()) as PurchaseRequest;
}

export interface ReportProgressDeps extends PurchaseRequestsDeps {
  id: string;
  actionId: string;
  decision: GuardianDecisionType;
  reasons: string[];
}

/** Reports the Guardian's authorization decision for a claimed purchase request, moving it to AUTHORIZED. */
export async function reportProgress(deps: ReportProgressDeps): Promise<PurchaseRequest> {
  const agentFetch = deps.agentFetch ?? signedAgentFetch;
  const response = await agentFetch(
    deps.agentAccount,
    deps.baseUrl,
    'POST',
    `/x402/purchase-requests/${deps.id}/progress`,
    { actionId: deps.actionId, decision: deps.decision, reasons: deps.reasons },
  );
  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`POST /x402/purchase-requests/${deps.id}/progress failed: ${response.status} ${errorBody}`);
  }
  return (await response.json()) as PurchaseRequest;
}

export interface ReportResultDeps extends PurchaseRequestsDeps {
  id: string;
  status: 'PAID' | 'BLOCKED' | 'REJECTED' | 'EXPIRED' | 'FAILED';
  actionId?: string;
  decision?: GuardianDecisionType;
  reasons?: string[];
  transactionHash?: string;
  response?: unknown;
  error?: string;
}

/** Reports the terminal (or blocked) outcome of a claimed purchase request. */
export async function reportResult(deps: ReportResultDeps): Promise<PurchaseRequest> {
  const agentFetch = deps.agentFetch ?? signedAgentFetch;
  const response = await agentFetch(
    deps.agentAccount,
    deps.baseUrl,
    'POST',
    `/x402/purchase-requests/${deps.id}/result`,
    {
      status: deps.status,
      actionId: deps.actionId,
      decision: deps.decision,
      reasons: deps.reasons,
      transactionHash: deps.transactionHash,
      response: deps.response,
      error: deps.error,
    },
  );
  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`POST /x402/purchase-requests/${deps.id}/result failed: ${response.status} ${errorBody}`);
  }
  return (await response.json()) as PurchaseRequest;
}
