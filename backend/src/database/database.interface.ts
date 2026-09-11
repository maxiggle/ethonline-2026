export interface TreasuryActionRow {
  id: string;
  target: string;
  value: string;
  data: string;
  token: string;
  recipient: string;
  amount: string;
  agent_address: string;
  justification: string;
  status: string;
  risk_score: number;
  requires_human_approval: boolean | number;
  nonce: number;
  deadline: number;
  signature?: string | null;
  tx_hash?: string | null;
  created_at: string;
  updated_at: string;
}

export interface TreasuryMandateRow {
  chain_id: number;
  safe_address: string;
  guard_address: string;
  autonomous_agent: string;
  human_signer: string;
  max_autonomous_amount: string;
  daily_autonomous_limit: string;
  approved_recipients: string; // JSON string
  approved_tokens: string;     // JSON string
  updated_at: string;
}

export interface DailySpentLedgerRow {
  day_id: number;
  cumulative_spent: string;
  updated_at: string;
}

export interface HumanBindingRow {
  signer_address: string;
  nullifier_hash: string;
  bound_at: string;
  expires_at: string;
}
