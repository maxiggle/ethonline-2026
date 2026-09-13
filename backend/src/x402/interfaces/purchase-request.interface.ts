import { GuardianDecisionType } from '../../domain/guardian-decision.entity';

export type PurchaseRequestStatus =
  | 'QUEUED'
  | 'PROCESSING'
  | 'AUTHORIZED'
  | 'PAID'
  | 'BLOCKED'
  | 'REJECTED'
  | 'EXPIRED'
  | 'FAILED';

export const PURCHASE_REQUEST_TERMINAL_STATUSES: PurchaseRequestStatus[] = [
  'PAID',
  'BLOCKED',
  'REJECTED',
  'EXPIRED',
  'FAILED',
];

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
  response: Record<string, unknown> | null;
  error: string | null;
  createdAt: string;
  updatedAt: string;
}
