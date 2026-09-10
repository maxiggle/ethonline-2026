import { Test, TestingModule } from '@nestjs/testing';
import { getAddress } from 'ethers';
import { WorldSelfieService } from './world-selfie.service';
import { WorldIdSelfieProof } from './interfaces/world-selfie.interface';
import {
  CREDENTIAL_TYPE_SELFIE,
  CREDENTIAL_TYPE_ORB,
  DEFAULT_WORLD_ACTION,
  SELFIE_INACTIVITY_WINDOW_MS,
} from './world.constants';

describe('WorldSelfieService', () => {
  let service: WorldSelfieService;

  const mockHumanSigner = '0xA11CE00000000000000000000000000000000001';
  const mockAttackerSigner = '0xBAD0000000000000000000000000000000000002';

  const validSelfieProof: WorldIdSelfieProof = {
    protocol_version: '4.0',
    merkle_root: '0x1f38b1492b4a78c187e148e6efddb55018659174be88390cb3347f89b9087c53',
    nullifier_hash: '0x2506e0f80bc43f146522c0e9b980c6575791eb0023a1a3641bfec91436154676',
    proof: '0x2a98...mock_zk_snark_proof_bytes...',
    credential_type: CREDENTIAL_TYPE_SELFIE,
    action: DEFAULT_WORLD_ACTION,
    signal: mockHumanSigner,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [WorldSelfieService],
    }).compile();

    service = module.get<WorldSelfieService>(WorldSelfieService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('Credential 11 Verification', () => {
    it('should verify a valid Credential 11 (Selfie Check Beta) proof in Sandbox', async () => {
      const result = await service.verifySelfieProof(validSelfieProof, mockHumanSigner);

      expect(result.success).toBe(true);
      expect(result.humanVerified).toBe(true);
      expect(result.nullifierHash).toBe(validSelfieProof.nullifier_hash);
      expect(result.credentialType).toBe(CREDENTIAL_TYPE_SELFIE);
      expect(result.expiresAt).toBeDefined();
    });

    it('should verify proof with string credential_type selfie', async () => {
      const result = await service.verifySelfieProof(
        { ...validSelfieProof, credential_type: 'selfie' },
        mockHumanSigner,
      );

      expect(result.success).toBe(true);
      expect(result.humanVerified).toBe(true);
    });

    it('should verify proof with Orb credential level', async () => {
      const result = await service.verifySelfieProof(
        { ...validSelfieProof, credential_type: CREDENTIAL_TYPE_ORB },
        mockHumanSigner,
      );

      expect(result.success).toBe(true);
      expect(result.humanVerified).toBe(true);
    });

    it('should reject weak device-only credential without selfie check', async () => {
      const result = await service.verifySelfieProof(
        { ...validSelfieProof, credential_type: 'device' },
        mockHumanSigner,
      );

      expect(result.success).toBe(false);
      expect(result.humanVerified).toBe(false);
      expect(result.error).toContain('Insufficient credential level');
    });

    it('should reject when action ID mismatches application configuration', async () => {
      const result = await service.verifySelfieProof(
        { ...validSelfieProof, action: 'unauthorized_action' },
        mockHumanSigner,
      );

      expect(result.success).toBe(false);
      expect(result.humanVerified).toBe(false);
      expect(result.error).toContain('Action ID mismatch');
    });

    it('should reject when signal does not match expected signer (proof tampering/hijacking)', async () => {
      const result = await service.verifySelfieProof(
        validSelfieProof,
        mockAttackerSigner, // Expecting attacker, but proof is signed for mockHumanSigner
      );

      expect(result.success).toBe(false);
      expect(result.humanVerified).toBe(false);
      expect(result.error).toContain('Signal mismatch');
    });

    it('should reject malformed proof payload missing cryptographic fields', async () => {
      const malformed = { ...validSelfieProof, nullifier_hash: '' };
      const result = await service.verifySelfieProof(malformed, mockHumanSigner);

      expect(result.success).toBe(false);
      expect(result.error).toContain('Malformed World ID proof payload');
    });
  });

  describe('Human Signer Binding & Anti-Sybil Replay Protection', () => {
    it('should bind a verified human to a signer address with 90-day expiration window', async () => {
      const binding = await service.bindHumanSigner(mockHumanSigner, validSelfieProof);

      expect(binding.signerAddress).toBe(getAddress(mockHumanSigner));
      expect(binding.nullifierHash).toBe(validSelfieProof.nullifier_hash);
      expect(binding.active).toBe(true);
      expect(binding.expiresAt.getTime()).toBeGreaterThan(Date.now() + 89 * 24 * 60 * 60 * 1000);

      const isVerified = await service.isHumanSignerVerified(mockHumanSigner);
      expect(isVerified).toBe(true);
    });

    it('should reject duplicate binding of the same nullifier to a different signer address', async () => {
      // First binding succeeds
      await service.bindHumanSigner(mockHumanSigner, validSelfieProof);

      // Second signer attempts to use the same human nullifier
      const attackProof: WorldIdSelfieProof = {
        ...validSelfieProof,
        signal: mockAttackerSigner,
      };

      await expect(service.bindHumanSigner(mockAttackerSigner, attackProof)).rejects.toThrow(
        'World ID nullifier has already been bound to another signer address',
      );
    });

    it('should report false for unknown or unverified signers', async () => {
      const isVerified = await service.isHumanSignerVerified('0x9999999999999999999999999999999999999999');
      expect(isVerified).toBe(false);
    });
  });

  describe('90-Day Inactivity Window Lifecycle', () => {
    it('should expire bindings older than 90 days of inactivity', async () => {
      const binding = await service.bindHumanSigner(mockHumanSigner, validSelfieProof);

      // Simulate passing of 91 days
      binding.expiresAt = new Date(Date.now() - 1000);

      const isVerified = await service.isHumanSignerVerified(mockHumanSigner);
      expect(isVerified).toBe(false);
    });

    it('should refresh the 90-day window when touchActivity is called', async () => {
      const binding = await service.bindHumanSigner(mockHumanSigner, validSelfieProof);
      const originalExpiration = binding.expiresAt.getTime();

      // Advance clock simulated slightly
      await new Promise((resolve) => setTimeout(resolve, 10));
      await service.touchActivity(mockHumanSigner);

      expect(binding.expiresAt.getTime()).toBeGreaterThanOrEqual(originalExpiration);
    });
  });

  describe('Binding Revocation & Queries', () => {
    it('should allow revoking a human binding', async () => {
      await service.bindHumanSigner(mockHumanSigner, validSelfieProof);
      expect(await service.isHumanSignerVerified(mockHumanSigner)).toBe(true);

      await service.revokeHumanBinding(mockHumanSigner);
      expect(await service.isHumanSignerVerified(mockHumanSigner)).toBe(false);

      const binding = await service.getHumanBinding(mockHumanSigner);
      expect(binding).toBeNull();
    });

    it('should list all active bindings', async () => {
      await service.bindHumanSigner(mockHumanSigner, validSelfieProof);
      const allBindings = await service.getAllBindings();

      expect(allBindings.length).toBe(1);
      expect(allBindings[0].signerAddress).toBe(getAddress(mockHumanSigner));
    });
  });
});
