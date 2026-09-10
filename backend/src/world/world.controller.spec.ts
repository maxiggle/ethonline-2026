import { Test, TestingModule } from '@nestjs/testing';
import { getAddress } from 'ethers';
import { WorldController } from './world.controller';
import { WorldSelfieService } from './world-selfie.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { WorldIdSelfieProof } from './interfaces/world-selfie.interface';
import { DEFAULT_WORLD_ACTION } from './world.constants';

describe('WorldController', () => {
  let controller: WorldController;
  let service: WorldSelfieService;

  const mockHumanSigner = getAddress('0xa11ce00000000000000000000000000000000001');

  const validProof: WorldIdSelfieProof = {
    protocol_version: '4.0',
    merkle_root: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    nullifier_hash: '0xnullifier11111111111111111111111111111111111111111111111111111111',
    proof: '0xproofbytes11111111111111111111111111111111111111111111111111111111',
    credential_type: 11,
    action: DEFAULT_WORLD_ACTION,
    signal: mockHumanSigner,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [WorldController],
      providers: [WorldSelfieService],
    }).compile();

    controller = module.get<WorldController>(WorldController);
    service = module.get<WorldSelfieService>(WorldSelfieService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should verify a valid selfie proof', async () => {
    const res = await controller.verifySelfie({
      proofPayload: validProof,
      expectedSigner: mockHumanSigner,
    });

    expect(res.success).toBe(true);
    expect(res.humanVerified).toBe(true);
    expect(res.credentialType).toBe(11);
    expect(res.nullifierHash).toBe(validProof.nullifier_hash);
  });

  it('should bind a verified human signer', async () => {
    const binding = await controller.bindHumanSigner({
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    expect(binding.signerAddress).toBe(mockHumanSigner);
    expect(binding.nullifierHash).toBe(validProof.nullifier_hash);
  });

  it('should throw BadRequestException if binding fails', async () => {
    const invalidProof = { ...validProof, credential_type: 'device' as any };

    await expect(
      controller.bindHumanSigner({
        signerAddress: mockHumanSigner,
        proofPayload: invalidProof,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should return verification status and binding details', async () => {
    await controller.bindHumanSigner({
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    const status = await controller.getVerificationStatus(mockHumanSigner);
    expect(status.isVerified).toBe(true);
    expect(status.binding?.nullifierHash).toBe(validProof.nullifier_hash);
  });

  it('should return all registered bindings', async () => {
    await controller.bindHumanSigner({
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    const bindings = await controller.getAllBindings();
    expect(bindings.length).toBe(1);
    expect(bindings[0].signerAddress).toBe(mockHumanSigner);
  });

  it('should revoke human binding', async () => {
    await controller.bindHumanSigner({
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    const revokeRes = await controller.revokeBinding(mockHumanSigner);
    expect(revokeRes.revoked).toBe(true);

    const status = await controller.getVerificationStatus(mockHumanSigner);
    expect(status.isVerified).toBe(false);
  });

  it('should throw NotFoundException when revoking non-existent binding', async () => {
    await expect(
      controller.revokeBinding('0x0000000000000000000000000000000000000000'),
    ).rejects.toThrow(NotFoundException);
  });
});
