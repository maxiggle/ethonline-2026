export interface AgentEntity {
  id: string;
  userId: string;
  agentAddress: string;
  name: string;
  purpose?: string | null;
  safeAddress: string;
  guardAddress: string;
  chainId: number;
  status: 'ACTIVE' | 'PAUSED' | 'REVOKED';
  createdAt: string;
  updatedAt: string;
}
