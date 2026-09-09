export enum TreasuryActionStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  EXECUTED = 'EXECUTED',
}

export class TreasuryAction {
  id: string;
  target: string;
  value: string;
  data: string;
  token: string;
  recipient: string;
  amount: string;
  agentAddress: string;
  justification: string;
  status: TreasuryActionStatus;
  nonce: number;
  deadline: number;
  riskScore: number;
  requiresHumanApproval: boolean;
  signature?: string;
  txHash?: string;
  createdAt: Date;
  updatedAt: Date;
}
