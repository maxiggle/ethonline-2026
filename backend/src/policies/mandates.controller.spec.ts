import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { MandatesController } from './mandates.controller';
import { PolicyEngineService } from './policy-engine.service';
import { AgentsService } from '../agents/agents.service';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';

describe('MandatesController', () => {
  let controller: MandatesController;
  let policyEngine: PolicyEngineService;

  const agentsService = { assertAgentOwnership: jest.fn() };
  const request = {
    user: { id: 'did:privy:mandate_operator' },
  } as unknown as AuthenticatedRequest;
  const unownedAgentAddress = '0x2222222222222222222222222222222222222222';

  beforeEach(async () => {
    agentsService.assertAgentOwnership.mockReset();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [MandatesController],
      providers: [PolicyEngineService, { provide: AgentsService, useValue: agentsService }],
    })
      .overrideGuard(PrivyAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<MandatesController>(MandatesController);
    policyEngine = module.get<PolicyEngineService>(PolicyEngineService);
  });

  it('should keep the active mandate public for health checks and guard every mutation', () => {
    expect(
      Reflect.getMetadata(GUARDS_METADATA, MandatesController.prototype.getActiveMandate),
    ).toBeUndefined();
    expect(Reflect.getMetadata(GUARDS_METADATA, MandatesController.prototype.deployAgent)).toContain(
      PrivyAuthGuard,
    );
    expect(Reflect.getMetadata(GUARDS_METADATA, MandatesController.prototype.updateCaps)).toContain(
      PrivyAuthGuard,
    );
  });

  it('should refuse to deploy an agent the caller does not own', async () => {
    const originalAgent = policyEngine.getMandate().autonomousAgent;
    agentsService.assertAgentOwnership.mockRejectedValue(new ForbiddenException());

    await expect(
      controller.deployAgent(request, { agentAddress: unownedAgentAddress }),
    ).rejects.toThrow(ForbiddenException);

    expect(agentsService.assertAgentOwnership).toHaveBeenCalledWith(
      'did:privy:mandate_operator',
      unownedAgentAddress,
    );
    expect(policyEngine.getMandate().autonomousAgent).toBe(originalAgent);
  });

  it('should refuse cap changes unless the caller owns the mandate autonomous agent', async () => {
    const originalMaxAutonomousAmount = policyEngine.getMandate().maxAutonomousAmount;
    agentsService.assertAgentOwnership.mockRejectedValue(new ForbiddenException());

    await expect(
      controller.updateCaps(request, {
        maxAutonomousAmount: '999000000',
        dailyAutonomousLimit: '999000000',
      }),
    ).rejects.toThrow(ForbiddenException);

    expect(agentsService.assertAgentOwnership).toHaveBeenCalledWith(
      'did:privy:mandate_operator',
      policyEngine.getMandate().autonomousAgent,
    );
    expect(policyEngine.getMandate().maxAutonomousAmount).toBe(originalMaxAutonomousAmount);
  });
});
