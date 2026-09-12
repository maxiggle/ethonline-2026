import { Injectable, BadRequestException, Logger, Optional } from '@nestjs/common';
import { getAddress } from 'ethers';
import {
  WorldVerificationMode,
  WorldIdSelfieProof,
  SelfieVerificationResult,
  HumanBinding,
} from './interfaces/world-selfie.interface';
import {
  CREDENTIAL_TYPE_SELFIE,
  CREDENTIAL_TYPE_ORB,
  SELFIE_INACTIVITY_WINDOW_MS,
  DEFAULT_WORLD_RP_ID,
  DEFAULT_WORLD_ACTION,
  WORLD_VERIFY_ENDPOINT_V4,
} from './world.constants';
import { DatabaseService } from '../database/database.service';
import { HumanBindingRow } from '../database/database.interface';

@Injectable()
export class WorldSelfieService {
  private readonly logger = new Logger(WorldSelfieService.name);
  private mode: WorldVerificationMode;
  private rpId: string;
  private action: string;
  private verifyEndpoint: string;
  private readonly dbService: DatabaseService;

  // In-memory registries with database write-through persistence
  private readonly humanBindings = new Map<string, HumanBinding>();
  private readonly nullifierToSigner = new Map<string, string>();

  constructor(@Optional() dbService?: DatabaseService) {
    this.mode = (process.env.WORLD_ID_MODE as WorldVerificationMode) || 'SANDBOX';
    this.rpId = process.env.WORLD_RP_ID || DEFAULT_WORLD_RP_ID;
    this.action = process.env.WORLD_ACTION || DEFAULT_WORLD_ACTION;
    this.verifyEndpoint = process.env.WORLD_VERIFY_ENDPOINT || WORLD_VERIFY_ENDPOINT_V4;

    if (dbService) {
      this.dbService = dbService;
    } else {
      this.dbService = new DatabaseService();
      this.dbService.initialize(':memory:');
    }

    this.loadFromDatabase();
  }

  private loadFromDatabase(): void {
    try {
      const rows = this.dbService.querySync<HumanBindingRow>(
        'SELECT * FROM human_bindings',
      );
      for (const row of rows) {
        const binding: HumanBinding = {
          signerAddress: getAddress(row.signer_address),
          nullifierHash: row.nullifier_hash,
          credentialType: CREDENTIAL_TYPE_SELFIE,
          boundAt: new Date(row.bound_at),
          lastActiveAt: new Date(row.bound_at),
          expiresAt: new Date(row.expires_at),
          active: new Date(row.expires_at).getTime() > Date.now(),
        };
        this.humanBindings.set(binding.signerAddress, binding);
        this.nullifierToSigner.set(binding.nullifierHash, binding.signerAddress);
      }
    } catch {}
  }

  /**
   * Sets verification mode (SANDBOX vs CLOUD_API).
   */
  setMode(mode: WorldVerificationMode): void {
    this.mode = mode;
  }

  /**
   * Verifies a World ID Credential 11 (Selfie Check Beta) or Orb proof.
   */
  async verifySelfieProof(
    proof: WorldIdSelfieProof,
    expectedSignal?: string,
  ): Promise<SelfieVerificationResult> {
    if (!proof || !proof.nullifier_hash || !proof.merkle_root || !proof.proof) {
      return {
        success: false,
        humanVerified: false,
        error: 'Malformed World ID proof payload: missing required cryptographic fields',
      };
    }

    // 1. Verify Credential Type (Must be Credential 11 Selfie or Orb, not weak device-only)
    const isSelfieOrOrb =
      proof.credential_type === CREDENTIAL_TYPE_SELFIE ||
      proof.credential_type === 'selfie' ||
      proof.credential_type === CREDENTIAL_TYPE_ORB;

    if (!isSelfieOrOrb) {
      return {
        success: false,
        humanVerified: false,
        error: `Insufficient credential level: '${proof.credential_type}'. Requires Credential 11 (Selfie Check) or Orb.`,
      };
    }

    // 2. Verify Action ID
    if (proof.action !== this.action) {
      return {
        success: false,
        humanVerified: false,
        error: `Action ID mismatch: expected '${this.action}', received '${proof.action}'`,
      };
    }

    // 3. Verify Signal (Cryptographic binding to expected signer or agent address)
    if (expectedSignal && proof.signal) {
      try {
        const normalizedExpected = getAddress(expectedSignal);
        const normalizedSignal = getAddress(proof.signal);
        if (normalizedExpected !== normalizedSignal) {
          return {
            success: false,
            humanVerified: false,
            error: `Signal mismatch: proof bound to '${proof.signal}', expected '${expectedSignal}'`,
          };
        }
      } catch {
        if (proof.signal.toLowerCase() !== expectedSignal.toLowerCase()) {
          return {
            success: false,
            humanVerified: false,
            error: `Signal mismatch: proof bound to '${proof.signal}', expected '${expectedSignal}'`,
          };
        }
      }
    }

    // 4. Verification Execution: Sandbox vs Live API
    if (this.mode === 'SANDBOX') {
      return this.verifyInSandbox(proof);
    }

    return this.verifyWithCloudApi(proof);
  }

  /**
   * Binds a verified human identity (nullifier) to an authorized humanSigner address
   * with a 90-day inactivity window.
   */
  async bindHumanSigner(
    signerAddress: string,
    proof: WorldIdSelfieProof,
  ): Promise<HumanBinding> {
    const normalizedSigner = getAddress(signerAddress);

    // Verify proof
    const verification = await this.verifySelfieProof(proof, normalizedSigner);
    if (!verification.success) {
      throw new BadRequestException(`Selfie verification failed: ${verification.error}`);
    }

    const nullifierHash = proof.nullifier_hash;

    // Anti-Sybil / Anti-Replay Check: One human nullifier cannot be used by different signers
    let existingSigner = this.nullifierToSigner.get(nullifierHash);
    if (!existingSigner) {
      try {
        const row = this.dbService.getOneSync<HumanBindingRow>(
          'SELECT * FROM human_bindings WHERE nullifier_hash = ?',
          [nullifierHash],
        );
        if (row) {
          existingSigner = getAddress(row.signer_address);
        }
      } catch {}
    }

    if (existingSigner && existingSigner !== normalizedSigner) {
      throw new BadRequestException(
        `World ID nullifier has already been bound to another signer address: ${existingSigner}`,
      );
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + SELFIE_INACTIVITY_WINDOW_MS);

    const binding: HumanBinding = {
      signerAddress: normalizedSigner,
      nullifierHash,
      credentialType: proof.credential_type === 'orb' ? CREDENTIAL_TYPE_ORB : CREDENTIAL_TYPE_SELFIE,
      boundAt: now,
      lastActiveAt: now,
      expiresAt,
      active: true,
    };

    this.humanBindings.set(normalizedSigner, binding);
    this.nullifierToSigner.set(nullifierHash, normalizedSigner);

    try {
      this.dbService.runSync(
        `INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at)
         VALUES (?, ?, ?, ?)`,
        [
          normalizedSigner,
          nullifierHash,
          now.toISOString(),
          expiresAt.toISOString(),
        ],
      );
    } catch {}

    this.logger.log(`Human binding created: ${normalizedSigner} -> Nullifier ${nullifierHash.slice(0, 10)}... (Expires: ${expiresAt.toISOString()})`);
    return binding;
  }

  /**
   * Checks if a human signer has an active, non-expired Selfie Check credential.
   */
  async isHumanSignerVerified(signerAddress: string): Promise<boolean> {
    const normalized = getAddress(signerAddress);
    let binding = this.humanBindings.get(normalized);

    if (!binding) {
      try {
        const row = this.dbService.getOneSync<HumanBindingRow>(
          'SELECT * FROM human_bindings WHERE signer_address = ?',
          [normalized],
        );
        if (row) {
          binding = {
            signerAddress: normalized,
            nullifierHash: row.nullifier_hash,
            credentialType: CREDENTIAL_TYPE_SELFIE,
            boundAt: new Date(row.bound_at),
            lastActiveAt: new Date(row.bound_at),
            expiresAt: new Date(row.expires_at),
            active: new Date(row.expires_at).getTime() > Date.now(),
          };
          this.humanBindings.set(normalized, binding);
          this.nullifierToSigner.set(row.nullifier_hash, normalized);
        }
      } catch {}
    }

    if (!binding || !binding.active) {
      return false;
    }

    // Check 90-day inactivity window
    if (Date.now() > binding.expiresAt.getTime()) {
      this.logger.warn(`Human binding for ${normalized} expired due to 90-day inactivity window.`);
      binding.active = false;
      return false;
    }

    return true;
  }

  /**
   * Refreshes the 90-day inactivity timer upon verified operational transactions.
   */
  async touchActivity(signerAddress: string): Promise<void> {
    const normalized = getAddress(signerAddress);
    const binding = this.humanBindings.get(normalized);

    if (binding && binding.active) {
      const now = new Date();
      const expiresAt = new Date(now.getTime() + SELFIE_INACTIVITY_WINDOW_MS);
      binding.lastActiveAt = now;
      binding.expiresAt = expiresAt;

      try {
        this.dbService.runSync(
          'UPDATE human_bindings SET expires_at = ? WHERE signer_address = ?',
          [expiresAt.toISOString(), normalized],
        );
      } catch {}
    }
  }

  /**
   * Retrieves active human binding details.
   */
  async getHumanBinding(signerAddress: string): Promise<HumanBinding | null> {
    const normalized = getAddress(signerAddress);
    let binding = this.humanBindings.get(normalized);
    if (!binding) {
      try {
        const row = this.dbService.getOneSync<HumanBindingRow>(
          'SELECT * FROM human_bindings WHERE signer_address = ?',
          [normalized],
        );
        if (row) {
          binding = {
            signerAddress: normalized,
            nullifierHash: row.nullifier_hash,
            credentialType: CREDENTIAL_TYPE_SELFIE,
            boundAt: new Date(row.bound_at),
            lastActiveAt: new Date(row.bound_at),
            expiresAt: new Date(row.expires_at),
            active: new Date(row.expires_at).getTime() > Date.now(),
          };
          this.humanBindings.set(normalized, binding);
        }
      } catch {}
    }
    return binding || null;
  }

  /**
   * Revokes a human binding.
   */
  async revokeHumanBinding(signerAddress: string): Promise<void> {
    const normalized = getAddress(signerAddress);
    const binding = this.humanBindings.get(normalized);
    if (binding) {
      binding.active = false;
      this.humanBindings.delete(normalized);
      this.nullifierToSigner.delete(binding.nullifierHash);
    }
    try {
      this.dbService.runSync('DELETE FROM human_bindings WHERE signer_address = ?', [normalized]);
    } catch {}
  }

  /**
   * Lists all active human bindings.
   */
  async getAllBindings(): Promise<HumanBinding[]> {
    return Array.from(this.humanBindings.values());
  }

  private async verifyInSandbox(proof: WorldIdSelfieProof): Promise<SelfieVerificationResult> {
    // Check format of nullifier and root
    if (!proof.nullifier_hash.startsWith('0x') || proof.nullifier_hash.length < 10) {
      return {
        success: false,
        humanVerified: false,
        error: 'Invalid nullifier_hash format in Sandbox',
      };
    }

    const expiresAt = new Date(Date.now() + SELFIE_INACTIVITY_WINDOW_MS);

    return {
      success: true,
      nullifierHash: proof.nullifier_hash,
      credentialType: CREDENTIAL_TYPE_SELFIE,
      humanVerified: true,
      expiresAt,
    };
  }

  private async verifyWithCloudApi(proof: WorldIdSelfieProof): Promise<SelfieVerificationResult> {
    try {
      const response = await fetch(`${this.verifyEndpoint}/${this.rpId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(proof),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return {
          success: false,
          humanVerified: false,
          error: errorData.message || `World ID API error: ${response.statusText}`,
        };
      }

      const data = await response.json();
      return {
        success: true,
        nullifierHash: data.nullifier_hash || proof.nullifier_hash,
        credentialType: CREDENTIAL_TYPE_SELFIE,
        humanVerified: true,
        expiresAt: new Date(Date.now() + SELFIE_INACTIVITY_WINDOW_MS),
      };
    } catch (err) {
      return {
        success: false,
        humanVerified: false,
        error: `Network error connecting to World ID verification endpoint: ${err.message}`,
      };
    }
  }
}
