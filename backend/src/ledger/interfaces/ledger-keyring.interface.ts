import { TreasuryActionApprovalParams } from '../../crypto/interfaces/eip712.interface';

export type LedgerMode = 'MOCK_HARDWARE' | 'HEADLESS_CLI' | 'DIRECT_TRANSPORT';

export interface LedgerDeviceStatus {
  connected: boolean;
  mode: LedgerMode;
  model: string;
  address: string;
  derivationPath: string;
  keyRingInitialized: boolean;
}

export interface LedgerClearSignField {
  label: string;
  value: string;
  critical: boolean;
}

export interface LedgerClearSignPrompt {
  title: string;
  fields: LedgerClearSignField[];
  domain: string;
  digest: string;
  rawApproval: TreasuryActionApprovalParams;
}

export interface KeyRingSignResult {
  signature: string;
  signer: string;
  digest: string;
  encodedPayload: string;
  timestamp: number;
}

export interface KeyRingSecret {
  keyName: string;
  ciphertext: string;
  algorithm: string;
  createdAt: Date;
}
