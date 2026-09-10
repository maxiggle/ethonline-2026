export type WorldVerificationMode = 'SANDBOX' | 'CLOUD_API';

export type WorldCredentialType = 11 | 'selfie' | 'orb' | 'device';

export interface WorldIdSelfieProof {
  protocol_version?: string;
  merkle_root: string;
  nullifier_hash: string;
  proof: string;
  credential_type: WorldCredentialType;
  action: string;
  signal?: string;
}

export interface SelfieVerificationResult {
  success: boolean;
  nullifierHash?: string;
  credentialType?: number | string;
  humanVerified: boolean;
  expiresAt?: Date;
  error?: string;
}

export interface HumanBinding {
  signerAddress: string;
  nullifierHash: string;
  credentialType: number | string;
  boundAt: Date;
  lastActiveAt: Date;
  expiresAt: Date;
  active: boolean;
}
