import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { HDNodeWallet, Wallet, getAddress } from 'ethers';
import { DatabaseService } from '../database/database.service';
import { X402Config } from '../x402/x402.config';
import { WorldIdApproverService } from './world-id-approver.service';
import { WorldIdConfig } from './world-id.config';
import { WorldIdRequestClient, WorldIdRequestResult } from './world-id-request.client';
import { WorldIdVerifyClient } from './world-id-verify.client';

import type { hashSignal as hashSignalFn } from '@worldcoin/idkit-core' with { 'resolution-mode': 'import' };

// eslint-disable-next-line @typescript-eslint/no-var-requires
const idkitCore = require('@worldcoin/idkit-core');
const hashSignal: typeof hashSignalFn = idkitCore.hashSignal;

class FakeWorldIdRequestClient implements WorldIdRequestClient {
  public pollResult: any = { type: 'waiting_for_connection' };
  public lastSignal: string | null = null;

  async createOrbRequest(signal: string): Promise<WorldIdRequestResult> {
    this.lastSignal = signal;
    return {
      requestId: 'req-test-1',
      connectorUrl: 'https://staging.world.org/verify?t=test',
      pollOnce: async () => this.pollResult,
    };
  }
}

class FakeWorldIdVerifyClient implements WorldIdVerifyClient {
  public verifyResult: any = {
    success: true,
    results: [{ identifier: 'orb', success: true }],
  };
  public verifyError: Error | null = null;

  async verifyProof(_result: any): Promise<any> {
    if (this.verifyError) throw this.verifyError;
    return this.verifyResult;
  }
}

describe('WorldIdApproverService', () => {
  let approverWallet: HDNodeWallet;
  let otherWallet: HDNodeWallet;
  let approverAddress: string;
  let service: WorldIdApproverService;
  let dbService: DatabaseService;
  let requestClient: FakeWorldIdRequestClient;
  let verifyClient: FakeWorldIdVerifyClient;
  let worldIdConfig: WorldIdConfig;
  let x402Config: X402Config;

  beforeEach(async () => {
    approverWallet = Wallet.createRandom();
    otherWallet = Wallet.createRandom();
    approverAddress = getAddress(approverWallet.address);

    dbService = new DatabaseService();
    await dbService.initialize(':memory:');

    worldIdConfig = {
      isWorldIdRequired: true,
      isWorldIdConfigured: true,
      appId: 'app_staging_12345',
      rpId: 'rp_123456789abcdef0',
      signingKeyHex: '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff',
      action: 'chapter2-ledger-approver',
      environment: 'staging',
    };

    x402Config = {
      network: 'eip155:84532',
      facilitatorUrl: 'https://x402.org/facilitator',
      usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      payToAddress: '0x1111111111111111111111111111111111111111',
      partnerPayToAddress: '0x2222222222222222222222222222222222222222',
      publicBaseUrl: 'http://localhost:3001',
      approvedPayTo: ['0x1111111111111111111111111111111111111111'],
      autonomousLimit: 1000000n,
      dailyLimit: 5000000n,
      ledgerApproverAddress: approverAddress,
    };

    requestClient = new FakeWorldIdRequestClient();
    verifyClient = new FakeWorldIdVerifyClient();

    service = new WorldIdApproverService(
      worldIdConfig,
      x402Config,
      requestClient,
      verifyClient,
      dbService,
    );
  });

  afterEach(async () => {
    service.onModuleDestroy();
    await dbService.close();
    jest.useRealTimers();
  });

  describe('startOrbVerification', () => {
    it('throws 503 when World ID is unconfigured', async () => {
      const unconfiguredService = new WorldIdApproverService(
        { isWorldIdRequired: false, isWorldIdConfigured: false },
        x402Config,
        requestClient,
        verifyClient,
        dbService,
      );

      await expect(unconfiguredService.startOrbVerification('user-1')).rejects.toThrow(
        ServiceUnavailableException,
      );
    });

    it('creates verification session and returns WAITING_FOR_WORLD_APP immediately', async () => {
      const verification = await service.startOrbVerification('user-1');
      expect(verification.requestId).toBe('req-test-1');
      expect(verification.status).toBe('WAITING_FOR_WORLD_APP');
      expect(verification.connectorUrl).toBe('https://staging.world.org/verify?t=test');
      expect(verification.bindMessage).toBeNull();
      expect(verification.errorMessage).toBeNull();
      expect(requestClient.lastSignal).toBe(approverAddress);
    });
  });

  describe('polling loop and proof verification', () => {
    it('moves to AWAITING_CONFIRMATION then VERIFIED on successful proof', async () => {
      jest.useFakeTimers();

      requestClient.pollResult = { type: 'awaiting_confirmation' };
      const verification = await service.startOrbVerification('user-1');

      // First tick: awaiting_confirmation
      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();

      let current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('AWAITING_CONFIRMATION');
      expect(current.connectorUrl).toBe('https://staging.world.org/verify?t=test');

      // Second tick: confirmed with valid proof
      const signalHash = hashSignal(approverAddress);
      const testNullifier = '0xnullifier123';
      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: signalHash,
              nullifier: testNullifier,
              proof: '0xproof',
              merkle_root: '0xroot',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('VERIFIED');
      expect(current.connectorUrl).toBeNull();
      expect(current.bindMessage).toBe(`chapter2-world-bind:${testNullifier.toLowerCase()}`);
      expect(current.errorMessage).toBeNull();

      jest.useRealTimers();
    });

    it('fails when signal_hash does not match the approver address', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal('0x9999999999999999999999999999999999999999'),
              nullifier: '0xnullifier123',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('FAILED');
      expect(current.errorMessage).toContain('Signal hash does not match');

      jest.useRealTimers();
    });

    it('fails when identifier is not orb', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'device',
              signal_hash: hashSignal(approverAddress),
              nullifier: '0xnullifier123',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('FAILED');
      expect(current.errorMessage).toContain("Missing 'orb' response item");

      jest.useRealTimers();
    });

    it('fails when action does not match', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'wrong-action',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier: '0xnullifier123',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('FAILED');
      expect(current.errorMessage).toContain('Action mismatch');

      jest.useRealTimers();
    });

    it('fails when nullifier is already bound to another signer in human_bindings', async () => {
      jest.useFakeTimers();

      const nullifier = '0xnullifier_already_bound';
      await dbService.run(
        'INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)',
        [otherWallet.address, nullifier, new Date().toISOString(), new Date(Date.now() + 100000).toISOString()],
      );

      const verification = await service.startOrbVerification('user-1');

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier,
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('FAILED');
      expect(current.errorMessage).toContain('already bound to another signer address');

      jest.useRealTimers();
    });

    it('fails when verifyProof throws an error', async () => {
      jest.useFakeTimers();

      verifyClient.verifyError = new Error('World ID verification failed: [invalid_proof] Signature expired');
      const verification = await service.startOrbVerification('user-1');

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier: '0xnullifier123',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('FAILED');
      expect(current.errorMessage).toContain('World ID verification failed');

      jest.useRealTimers();
    });

    it('fails when IDKit poll reports failed with error code', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');

      requestClient.pollResult = {
        type: 'failed',
        error: 'rp_signature_expired',
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();

      const current = service.getOrbVerification('user-1', verification.requestId);
      expect(current.status).toBe('FAILED');
      expect(current.errorMessage).toContain('rp_signature_expired');

      jest.useRealTimers();
    });
  });

  describe('bindLedgerApprover', () => {
    it('successfully binds approver when signature is valid', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');
      const testNullifier = '0xnullifier_success';

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier: testNullifier,
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const verifiedSession = service.getOrbVerification('user-1', verification.requestId);
      expect(verifiedSession.status).toBe('VERIFIED');

      jest.useRealTimers();

      const signature = await approverWallet.signMessage(verifiedSession.bindMessage!);
      const approverStatus = await service.bindLedgerApprover('user-1', verification.requestId, signature);

      expect(approverStatus.isVerified).toBe(true);
      expect(approverStatus.credential).toBe('orb');
      expect(approverStatus.boundAt).toBeDefined();
      expect(approverStatus.expiresAt).toBeDefined();

      const sessionAfterBind = service.getOrbVerification('user-1', verification.requestId);
      expect(sessionAfterBind.status).toBe('BOUND');
    });

    it('throws 401 Unauthorized when signature is from another signer', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');
      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier: '0xnullifier_401',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();
      const verifiedSession = service.getOrbVerification('user-1', verification.requestId);
      jest.useRealTimers();

      const wrongSignature = await otherWallet.signMessage(verifiedSession.bindMessage!);
      await expect(
        service.bindLedgerApprover('user-1', verification.requestId, wrongSignature),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('throws 400 BadRequest when signature is malformed', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');
      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier: '0xnullifier_400',
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();
      jest.useRealTimers();

      await expect(
        service.bindLedgerApprover('user-1', verification.requestId, 'not-a-valid-hex-signature'),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws 404 NotFound when request does not exist or belongs to another user', async () => {
      await expect(
        service.bindLedgerApprover('wrong-user', 'req-test-1', '0x123'),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws 409 Conflict when session is not VERIFIED', async () => {
      const verification = await service.startOrbVerification('user-1');
      await expect(
        service.bindLedgerApprover('user-1', verification.requestId, '0x123'),
      ).rejects.toThrow(ConflictException);
    });

    it('throws 409 Conflict when nullifier is bound to another signer at bind time', async () => {
      jest.useFakeTimers();

      const verification = await service.startOrbVerification('user-1');
      const testNullifier = '0xnullifier_race_bound';

      requestClient.pollResult = {
        type: 'confirmed',
        result: {
          action: 'chapter2-ledger-approver',
          responses: [
            {
              identifier: 'orb',
              signal_hash: hashSignal(approverAddress),
              nullifier: testNullifier,
            },
          ],
        },
      };

      await jest.advanceTimersByTimeAsync(2000);
      await Promise.resolve();
      await Promise.resolve();

      const verifiedSession = service.getOrbVerification('user-1', verification.requestId);
      jest.useRealTimers();

      // Bind nullifier to another address before binding
      await dbService.run(
        'INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)',
        [otherWallet.address, testNullifier, new Date().toISOString(), new Date(Date.now() + 100000).toISOString()],
      );

      const signature = await approverWallet.signMessage(verifiedSession.bindMessage!);
      await expect(
        service.bindLedgerApprover('user-1', verification.requestId, signature),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('assertLedgerApproverVerifiedForApproval', () => {
    it('throws 403 Forbidden when required and approver has no active binding', async () => {
      await expect(service.assertLedgerApproverVerifiedForApproval()).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('throws 403 Forbidden when required and approver binding is expired', async () => {
      const expiredDate = new Date(Date.now() - 1000).toISOString();
      await dbService.run(
        'INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)',
        [approverAddress, '0xnullifier', expiredDate, expiredDate],
      );

      await expect(service.assertLedgerApproverVerifiedForApproval()).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('succeeds and extends expiry when required and active binding exists', async () => {
      const validUntil = new Date(Date.now() + 100000).toISOString();
      await dbService.run(
        'INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)',
        [approverAddress, '0xnullifier', new Date().toISOString(), validUntil],
      );

      await expect(service.assertLedgerApproverVerifiedForApproval()).resolves.toBeUndefined();

      const status = await service.getApproverStatus();
      expect(status.isVerified).toBe(true);
      const newExpiryTime = new Date(status.expiresAt!).getTime();
      expect(newExpiryTime).toBeGreaterThan(Date.now() + 89 * 24 * 60 * 60 * 1000);
    });

    it('is a no-op when World ID is not required', async () => {
      worldIdConfig.isWorldIdRequired = false;
      await expect(service.assertLedgerApproverVerifiedForApproval()).resolves.toBeUndefined();
    });
  });
});
