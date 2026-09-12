import { Test, TestingModule } from '@nestjs/testing';
import { AgentsController } from './agents.controller';
import { AgentsService } from './agents.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { BindAgentDto } from './dto/bind-agent.dto';

describe('AgentsController', () => {
  let controller: AgentsController;
  let service: AgentsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule, AuthModule],
      controllers: [AgentsController],
      providers: [AgentsService],
    }).compile();

    controller = module.get<AgentsController>(AgentsController);
    service = module.get<AgentsService>(AgentsService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('POST /agents/bind & GET /agents', () => {
    it('should bind agent for authenticated user and list them', async () => {
      const mockReq = {
        user: {
          id: 'did:privy:dave_test',
          email: 'dave@example.com',
        },
      };

      const dto: BindAgentDto = {
        agentAddress: '0x4444444444444444444444444444444444444444',
        name: 'Dave Agent',
        purpose: 'Test Agent',
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        chainId: 84532,
      };

      const bindRes = await controller.bindAgent(dto, mockReq);
      expect(bindRes.success).toBe(true);
      expect(bindRes.agent.name).toBe('Dave Agent');

      const listRes = await controller.getMyAgents(mockReq);
      expect(listRes.success).toBe(true);
      expect(listRes.agents.length).toBeGreaterThan(0);
      expect(listRes.agents[0].name).toBe('Dave Agent');
    });
  });
});
