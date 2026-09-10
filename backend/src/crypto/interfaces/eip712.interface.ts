export interface Eip712Domain {
  name: string;
  version: string;
  chainId: number | bigint;
  verifyingContract: string;
}

export interface TreasuryActionApprovalParams {
  actionId: string;
  agent: string;
  recipient: string;
  token: string;
  amount: bigint | string | number;
  nonce: bigint | string | number;
  deadline: bigint | string | number;
  mandateHash: string;
  riskScore: number;
}

export interface Eip712TypeProperty {
  name: string;
  type: string;
}

export interface Eip712TypedData {
  domain: Eip712Domain;
  types: Record<string, Eip712TypeProperty[]>;
  primaryType: string;
  message: Record<string, any>;
}

export interface EscalatedExecutionPayload {
  approval: TreasuryActionApprovalParams;
  signature: string;
}
