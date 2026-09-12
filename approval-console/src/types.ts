export interface TypedDataDomain {
  name?: string;
  version?: string;
  chainId?: number;
  verifyingContract?: string;
  salt?: string;
}

export interface TypedDataField {
  name: string;
  type: string;
}

export interface EscalationTypedData {
  domain: TypedDataDomain;
  types: Record<string, TypedDataField[]>;
  primaryType: string;
  message: Record<string, unknown>;
}

export interface PendingApproval {
  actionId: string;
  resourceUrl: string;
  amount: string;
  payTo: string;
  agentAddress: string;
  justification: string;
  riskScore: number;
  reasons: string[];
  typedData: EscalationTypedData;
  createdAt: string;
}

export interface ApprovalConfig {
  approverAddress: string;
  network: string;
  usdcAddress: string;
}

export interface DeviceSignature {
  r: string;
  s: string;
  v: number;
}
