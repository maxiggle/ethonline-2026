import { Test, TestingModule } from '@nestjs/testing';
import { getAddress } from 'ethers';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { WorldController } from './world.controller';
import { WorldSelfieService } from './world-selfie.service';
import { WorldIdSelfieProof } from './interfaces/world-selfie.interface';
import { DEFAULT_WORLD_ACTION } from './world.constants';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';

describe('WorldController', () => {
  let controller: WorldController;

  const mockHumanSigner = getAddress('0xa11ce00000000000000000000000000000000001');
  const otherOperatorWallet = getAddress('0xb0b0000000000000000000000000000000000002');

  const humanRequest = {
    user: { id: 'did:privy:human_operator', walletAddress: mockHumanSigner },
  } as unknown as AuthenticatedRequest;
  const otherOperatorRequest = {
    user: { id: 'did:privy:other_operator', walletAddress: otherOperatorWallet },
  } as unknown as AuthenticatedRequest;

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
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<WorldController>(WorldController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should require Privy authentication on every World ID route', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, WorldController);
    expect(guards).toContain(PrivyAuthGuard);
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

  it('should bind a verified human signer to the caller wallet', async () => {
    const binding = await controller.bindHumanSigner(humanRequest, {
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    expect(binding.signerAddress).toBe(mockHumanSigner);
    expect(binding.nullifierHash).toBe(validProof.nullifier_hash);
  });

  it('should refuse to bind a World ID proof to a wallet other than the caller', async () => {
    await expect(
      controller.bindHumanSigner(otherOperatorRequest, {
        signerAddress: mockHumanSigner,
        proofPayload: validProof,
      }),
    ).rejects.toThrow(ForbiddenException);

    const status = await controller.getVerificationStatus(mockHumanSigner);
    expect(status.isVerified).toBe(false);
  });

  it('should throw BadRequestException if binding fails', async () => {
    const invalidProof = { ...validProof, credential_type: 'device' as any };

    await expect(
      controller.bindHumanSigner(humanRequest, {
        signerAddress: mockHumanSigner,
        proofPayload: invalidProof,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should return verification status and binding details', async () => {
    await controller.bindHumanSigner(humanRequest, {
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    const status = await controller.getVerificationStatus(mockHumanSigner);
    expect(status.isVerified).toBe(true);
    expect(status.binding?.nullifierHash).toBe(validProof.nullifier_hash);
  });

  it('should return only the caller binding', async () => {
    await controller.bindHumanSigner(humanRequest, {
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    const callerBindings = await controller.getCallerBindings(humanRequest);
    expect(callerBindings.length).toBe(1);
    expect(callerBindings[0].signerAddress).toBe(mockHumanSigner);

    expect(await controller.getCallerBindings(otherOperatorRequest)).toEqual([]);
  });

  it('should revoke the caller human binding', async () => {
    await controller.bindHumanSigner(humanRequest, {
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    const revokeRes = await controller.revokeBinding(humanRequest, mockHumanSigner);
    expect(revokeRes.revoked).toBe(true);

    const status = await controller.getVerificationStatus(mockHumanSigner);
    expect(status.isVerified).toBe(false);
  });

  it("should refuse to revoke another wallet's binding", async () => {
    await controller.bindHumanSigner(humanRequest, {
      signerAddress: mockHumanSigner,
      proofPayload: validProof,
    });

    await expect(
      controller.revokeBinding(otherOperatorRequest, mockHumanSigner),
    ).rejects.toThrow(ForbiddenException);

    const status = await controller.getVerificationStatus(mockHumanSigner);
    expect(status.isVerified).toBe(true);
  });

  it('should throw NotFoundException when the caller has no binding to revoke', async () => {
    await expect(
      controller.revokeBinding(humanRequest, mockHumanSigner),
    ).rejects.toThrow(NotFoundException);
  });
});
