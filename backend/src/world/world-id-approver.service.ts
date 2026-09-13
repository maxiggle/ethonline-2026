import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  Optional,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { getAddress, verifyMessage } from 'ethers';
import { DatabaseService } from '../database/database.service';
import { HumanBindingRow } from '../database/database.interface';
import { X402Config } from '../x402/x402.config';
import { X402_CONFIG } from '../x402/x402.constants';
import { WORLD_ID_CONFIG, WorldIdConfig } from './world-id.config';
import { WORLD_ID_REQUEST_CLIENT, WorldIdRequestClient } from './world-id-request.client';
import { WORLD_ID_VERIFY_CLIENT, WorldIdVerifyClient } from './world-id-verify.client';

import type { hashSignal as hashSignalFn } from '@worldcoin/idkit-core' with { 'resolution-mode': 'import' };

// eslint-disable-next-line @typescript-eslint/no-var-requires
const idkitCore = require('@worldcoin/idkit-core');
const hashSignal: typeof hashSignalFn = idkitCore.hashSignal;

export type OrbVerificationStatus =
  | 'WAITING_FOR_WORLD_APP'
  | 'AWAITING_CONFIRMATION'
  | 'VERIFIED'
  | 'BOUND'
  | 'FAILED'
  | 'EXPIRED';

export interface ApproverStatus {
  approverAddress: string;
  isWorldIdRequired: boolean;
  isWorldIdConfigured: boolean;
  environment: 'staging' | 'production' | null;
  isVerified: boolean;
  credential: 'orb' | null;
  boundAt: string | null;
  expiresAt: string | null;
}

export interface OrbVerification {
  requestId: string;
  status: OrbVerificationStatus;
  connectorUrl: string | null;
  expiresAt: string;
  bindMessage: string | null;
  errorMessage: string | null;
}

interface VerificationSession {
  requestId: string;
  userId: string;
  status: OrbVerificationStatus;
  connectorUrl: string | null;
  expiresAt: string;
  bindMessage: string | null;
  errorMessage: string | null;
  nullifier?: string;
  pollInterval?: NodeJS.Timeout;
}

const SESSION_TTL_MS = 15 * 60 * 1000;
const BINDING_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const POLL_INTERVAL_MS = 2000;

@Injectable()
export class WorldIdApproverService implements OnModuleDestroy {
  private readonly logger = new Logger(WorldIdApproverService.name);
  private readonly sessions = new Map<string, VerificationSession>();
  private readonly dbService: DatabaseService;

  onModuleDestroy(): void {
    for (const session of this.sessions.values()) {
      this.stopPolling(session);
    }
    this.sessions.clear();
  }

  constructor(
    @Inject(WORLD_ID_CONFIG) private readonly config: WorldIdConfig,
    @Inject(X402_CONFIG) private readonly x402Config: X402Config,
    @Inject(WORLD_ID_REQUEST_CLIENT) private readonly requestClient: WorldIdRequestClient,
    @Inject(WORLD_ID_VERIFY_CLIENT) private readonly verifyClient: WorldIdVerifyClient,
    @Optional() dbService?: DatabaseService,
  ) {
    if (dbService) {
      this.dbService = dbService;
    } else {
      this.dbService = new DatabaseService();
      this.dbService.initialize();
    }
  }

  async startOrbVerification(userId: string): Promise<OrbVerification> {
    if (!this.config.isWorldIdConfigured) {
      throw new ServiceUnavailableException('World ID is not configured');
    }

    const checksummedApprover = getAddress(this.x402Config.ledgerApproverAddress);
    const request = await this.requestClient.createOrbRequest(checksummedApprover);

    const expiresAt = new Date(Date.now() + SESSION_TTL_MS).toISOString();
    const session: VerificationSession = {
      requestId: request.requestId,
      userId,
      status: 'WAITING_FOR_WORLD_APP',
      connectorUrl: request.connectorUrl,
      expiresAt,
      bindMessage: null,
      errorMessage: null,
    };

    this.sessions.set(request.requestId, session);

    this.startPollingLoop(session, request.pollOnce, checksummedApprover);

    return this.toOrbVerificationResponse(session);
  }

  private startPollingLoop(
    session: VerificationSession,
    pollOnce: () => Promise<any>,
    checksummedApprover: string,
  ): void {
    const timer = setInterval(async () => {
      try {
        if (new Date(session.expiresAt).getTime() <= Date.now()) {
          this.stopPolling(session);
          if (session.status !== 'BOUND') {
            session.status = 'EXPIRED';
            session.connectorUrl = null;
          }
          return;
        }

        const pollResult = await pollOnce();
        if (!pollResult) return;

        if (pollResult.type === 'awaiting_confirmation') {
          if (session.status === 'WAITING_FOR_WORLD_APP') {
            session.status = 'AWAITING_CONFIRMATION';
          }
          return;
        }

        if (pollResult.type === 'failed') {
          this.stopPolling(session);
          session.status = 'FAILED';
          session.connectorUrl = null;
          session.errorMessage = this.formatIdkitError(pollResult.error);
          return;
        }

        if (pollResult.type === 'confirmed') {
          this.stopPolling(session);
          await this.handleConfirmedProof(session, pollResult.result, checksummedApprover);
        }
      } catch (err: any) {
        this.stopPolling(session);
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = err.message || 'Verification failed';
      }
    }, POLL_INTERVAL_MS);

    session.pollInterval = timer;
  }

  private stopPolling(session: VerificationSession): void {
    if (session.pollInterval) {
      clearInterval(session.pollInterval);
      session.pollInterval = undefined;
    }
  }

  private async handleConfirmedProof(
    session: VerificationSession,
    idkitResult: any,
    checksummedApprover: string,
  ): Promise<void> {
    try {
      // Check 1: World Developer Portal verify
      const verifyResponse = await this.verifyClient.verifyProof(idkitResult);
      if (!verifyResponse || verifyResponse.success !== true) {
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = 'World ID verify API rejected the proof';
        return;
      }

      const orbResult = Array.isArray(verifyResponse.results)
        ? verifyResponse.results.find((r: any) => r.identifier === 'orb')
        : null;
      if (!orbResult || orbResult.success !== true) {
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = 'World ID proof for orb credential failed verification';
        return;
      }

      // Check 2: Action match
      if (idkitResult.action !== this.config.action) {
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = `Action mismatch: expected '${this.config.action}', got '${idkitResult.action}'`;
        return;
      }

      // Check 3: Response item with identifier === 'orb'
      const responses: any[] = idkitResult.responses || [];
      const orbResponse = responses.find((item) => item.identifier === 'orb');
      if (!orbResponse) {
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = "Missing 'orb' response item in proof payload";
        return;
      }

      // Check 4: signal_hash equals hashSignal(approverAddress) (case-insensitive hex compare)
      const expectedSignalHash = hashSignal(checksummedApprover);
      if (
        !orbResponse.signal_hash ||
        orbResponse.signal_hash.toLowerCase() !== expectedSignalHash.toLowerCase()
      ) {
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = 'Signal hash does not match configured Ledger approver address';
        return;
      }

      // Check 5: nullifier lowercased isn't bound to a different signer
      const nullifier = (orbResponse.nullifier || '').toLowerCase();
      if (!nullifier) {
        session.status = 'FAILED';
        session.connectorUrl = null;
        session.errorMessage = 'Proof is missing nullifier';
        return;
      }

      const existingBindings = await this.dbService.query<HumanBindingRow>(
        'SELECT * FROM human_bindings WHERE nullifier_hash = ?',
        [nullifier],
      );
      for (const row of existingBindings) {
        if (getAddress(row.signer_address) !== checksummedApprover) {
          session.status = 'FAILED';
          session.connectorUrl = null;
          session.errorMessage = 'This World ID nullifier is already bound to another signer address';
          return;
        }
      }

      session.status = 'VERIFIED';
      session.nullifier = nullifier;
      session.bindMessage = `chapter2-world-bind:${nullifier}`;
      session.connectorUrl = null;
    } catch (err: any) {
      session.status = 'FAILED';
      session.connectorUrl = null;
      session.errorMessage = err.message || 'Error processing verified proof';
    }
  }

  getOrbVerification(userId: string, requestId: string): OrbVerification {
    const session = this.sessions.get(requestId);
    if (!session || session.userId !== userId) {
      throw new NotFoundException('Verification request not found');
    }

    if (new Date(session.expiresAt).getTime() <= Date.now() && session.status !== 'BOUND') {
      session.status = 'EXPIRED';
      session.connectorUrl = null;
    }

    return this.toOrbVerificationResponse(session);
  }

  async bindLedgerApprover(
    userId: string,
    requestId: string,
    signature: string,
  ): Promise<ApproverStatus> {
    const session = this.sessions.get(requestId);
    if (!session || session.userId !== userId) {
      throw new NotFoundException('Verification request not found');
    }

    if (new Date(session.expiresAt).getTime() <= Date.now() || session.status !== 'VERIFIED') {
      throw new ConflictException('Verification session is not verified or has expired');
    }

    if (!session.bindMessage || !session.nullifier) {
      throw new ConflictException('Verification session is missing binding details');
    }

    const checksummedApprover = getAddress(this.x402Config.ledgerApproverAddress);

    let recovered: string;
    try {
      recovered = verifyMessage(session.bindMessage, signature);
    } catch {
      throw new BadRequestException('Malformed signature');
    }

    if (getAddress(recovered) !== checksummedApprover) {
      throw new UnauthorizedException('Signature does not match the configured Ledger approver');
    }

    // Re-run nullifier bound to another signer check
    const existingBindings = await this.dbService.query<HumanBindingRow>(
      'SELECT * FROM human_bindings WHERE nullifier_hash = ?',
      [session.nullifier],
    );
    for (const row of existingBindings) {
      if (getAddress(row.signer_address) !== checksummedApprover) {
        throw new ConflictException('This World ID nullifier is already bound to another signer address');
      }
    }

    const now = new Date();
    const boundAt = now.toISOString();
    const expiresAt = new Date(now.getTime() + BINDING_TTL_MS).toISOString();

    await this.dbService.run(
      'INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)',
      [checksummedApprover, session.nullifier, boundAt, expiresAt],
    );

    session.status = 'BOUND';
    this.stopPolling(session);

    return this.getApproverStatus();
  }

  async getApproverStatus(): Promise<ApproverStatus> {
    const checksummedApprover = getAddress(this.x402Config.ledgerApproverAddress);
    const rows = await this.dbService.query<HumanBindingRow>(
      'SELECT * FROM human_bindings WHERE signer_address = ?',
      [checksummedApprover],
    );

    let isVerified = false;
    let credential: 'orb' | null = null;
    let boundAt: string | null = null;
    let expiresAt: string | null = null;

    if (rows.length > 0) {
      const binding = rows[0];
      const expiry = new Date(binding.expires_at).getTime();
      if (expiry > Date.now()) {
        isVerified = true;
        credential = 'orb';
        boundAt = binding.bound_at;
        expiresAt = binding.expires_at;
      }
    }

    return {
      approverAddress: checksummedApprover,
      isWorldIdRequired: this.config.isWorldIdRequired,
      isWorldIdConfigured: this.config.isWorldIdConfigured,
      environment: this.config.isWorldIdConfigured ? this.config.environment! : null,
      isVerified,
      credential,
      boundAt,
      expiresAt,
    };
  }

  async assertLedgerApproverVerifiedForApproval(): Promise<void> {
    if (!this.config.isWorldIdRequired) {
      return;
    }

    const checksummedApprover = getAddress(this.x402Config.ledgerApproverAddress);
    const rows = await this.dbService.query<HumanBindingRow>(
      'SELECT * FROM human_bindings WHERE signer_address = ?',
      [checksummedApprover],
    );

    if (rows.length === 0 || new Date(rows[0].expires_at).getTime() <= Date.now()) {
      throw new ForbiddenException('The Ledger approver has no active World ID Orb verification');
    }

    // Extend binding expiry to now + 90 days
    const newExpiresAt = new Date(Date.now() + BINDING_TTL_MS).toISOString();
    await this.dbService.run(
      'UPDATE human_bindings SET expires_at = ? WHERE signer_address = ?',
      [newExpiresAt, checksummedApprover],
    );
  }

  private toOrbVerificationResponse(session: VerificationSession): OrbVerification {
    return {
      requestId: session.requestId,
      status: session.status,
      connectorUrl:
        session.status === 'WAITING_FOR_WORLD_APP' || session.status === 'AWAITING_CONFIRMATION'
          ? session.connectorUrl
          : null,
      expiresAt: session.expiresAt,
      bindMessage: session.status === 'VERIFIED' ? session.bindMessage : null,
      errorMessage: session.status === 'FAILED' ? session.errorMessage : null,
    };
  }

  private formatIdkitError(error: any): string {
    const errorString = String(error);
    switch (errorString) {
      case 'rp_signature_expired':
        return 'The relying party signature expired (rp_signature_expired)';
      case 'unknown_rp':
        return 'Unknown relying party configuration (unknown_rp)';
      case 'invalid_rp_signature':
        return 'Invalid relying party signature (invalid_rp_signature)';
      case 'user_rejected':
        return 'Verification was cancelled by the user in World App';
      case 'verification_rejected':
        return 'Verification was rejected by World App';
      default:
        return `World ID verification failed: ${errorString}`;
    }
  }
}
