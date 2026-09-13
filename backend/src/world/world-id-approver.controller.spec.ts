import { Test, TestingModule } from '@nestjs/testing';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { WorldIdApproverController } from './world-id-approver.controller';
import {
  ApproverStatus,
  OrbVerification,
  WorldIdApproverService,
} from './world-id-approver.service';

describe('WorldIdApproverController', () => {
  let controller: WorldIdApproverController;
  let service: WorldIdApproverService;

  const mockApproverStatus: ApproverStatus = {
    approverAddress: '0x1111111111111111111111111111111111111111',
    isWorldIdRequired: true,
    isWorldIdConfigured: true,
    environment: 'staging',
    isVerified: true,
    credential: 'orb',
    boundAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + 100000).toISOString(),
  };

  const mockOrbVerification: OrbVerification = {
    requestId: 'req-123',
    status: 'WAITING_FOR_WORLD_APP',
    connectorUrl: 'https://staging.world.org/verify?t=123',
    expiresAt: new Date().toISOString(),
    bindMessage: null,
    errorMessage: null,
  };

  const mockRequest = {
    user: { id: 'did:privy:user_123', walletAddress: '0x1111111111111111111111111111111111111111' },
  } as unknown as AuthenticatedRequest;

  beforeEach(async () => {
    const mockService = {
      getApproverStatus: jest.fn().mockResolvedValue(mockApproverStatus),
      startOrbVerification: jest.fn().mockResolvedValue(mockOrbVerification),
      getOrbVerification: jest.fn().mockReturnValue(mockOrbVerification),
      bindLedgerApprover: jest.fn().mockResolvedValue(mockApproverStatus),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [WorldIdApproverController],
      providers: [
        {
          provide: WorldIdApproverService,
          useValue: mockService,
        },
      ],
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<WorldIdApproverController>(WorldIdApproverController);
    service = module.get<WorldIdApproverService>(WorldIdApproverService);
  });

  it('should be protected by PrivyAuthGuard', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, WorldIdApproverController);
    expect(guards).toContain(PrivyAuthGuard);
  });

  it('GET /world/approver/status returns approver status', async () => {
    const result = await controller.getStatus();
    expect(result).toEqual(mockApproverStatus);
    expect(service.getApproverStatus).toHaveBeenCalled();
  });

  it('POST /world/approver/orb-verifications starts verification', async () => {
    const result = await controller.startOrbVerification(mockRequest);
    expect(result).toEqual(mockOrbVerification);
    expect(service.startOrbVerification).toHaveBeenCalledWith('did:privy:user_123');
  });

  it('GET /world/approver/orb-verifications/:requestId gets verification session', async () => {
    const result = await controller.getOrbVerification(mockRequest, 'req-123');
    expect(result).toEqual(mockOrbVerification);
    expect(service.getOrbVerification).toHaveBeenCalledWith('did:privy:user_123', 'req-123');
  });

  it('POST /world/approver/orb-verifications/:requestId/bind binds approver', async () => {
    const result = await controller.bindLedgerApprover(mockRequest, 'req-123', {
      signature: '0xsignature123',
    });
    expect(result).toEqual(mockApproverStatus);
    expect(service.bindLedgerApprover).toHaveBeenCalledWith(
      'did:privy:user_123',
      'req-123',
      '0xsignature123',
    );
  });
});
