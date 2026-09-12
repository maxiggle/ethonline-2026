import { Test, TestingModule } from '@nestjs/testing';
import { AgentsService } from './agents.service';
import { DatabaseModule } from '../database/database.module';
import { DatabaseService } from '../database/database.service';
import { BindAgentDto } from './dto/bind-agent.dto';

describe('AgentsService', () => {
  let service: AgentsService;
  let dbService: DatabaseService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule],
      providers: [AgentsService],
    }).compile();

    service = module.get<AgentsService>(AgentsService);
    dbService = module.get<DatabaseService>(DatabaseService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('bindAgent & getAgentsForUser', () => {
    it('should bind an agent to a user and retrieve it', async () => {
      const userId = 'did:privy:alice_test';
      const dto: BindAgentDto = {
        agentAddress: '0x1111111111111111111111111111111111111111',
        name: 'Autonomous Compute Buyer',
        purpose: 'Automated GPU reservation and payment',
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        chainId: 84532,
      };

      const agent = await service.bindAgent(userId, dto);
      expect(agent).toBeDefined();
      expect(agent.name).toBe('Autonomous Compute Buyer');
      expect(agent.userId).toBe(userId);
      expect(agent.status).toBe('ACTIVE');

      const userAgents = await service.getAgentsForUser(userId);
      expect(userAgents.length).toBeGreaterThan(0);
      expect(userAgents[0].name).toBe('Autonomous Compute Buyer');
    });

    it('should verify agent ownership correctly', async () => {
      const userId = 'did:privy:bob_test';
      const agentAddress = '0x3333333333333333333333333333333333333333';
      const dto: BindAgentDto = {
        agentAddress,
        name: 'Bob Agent',
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        chainId: 84532,
      };

      await service.bindAgent(userId, dto);

      const isOwner = await service.verifyAgentOwnership(userId, agentAddress);
      expect(isOwner).toBe(true);

      const isNotOwner = await service.verifyAgentOwnership('did:privy:charlie', agentAddress);
      expect(isNotOwner).toBe(false);
    });

    it('should auto-bind real user walletAddress when user exists', async () => {
      const userId = 'did:privy:dave_with_wallet';
      const realWallet = '0x4444444444444444444444444444444444444444';
      const now = new Date().toISOString();

      await dbService.run(
        'INSERT INTO "user" (id, email, name, "avatarUrl", "walletAddress", "createdAt", "updatedAt") VALUES (?, ?, ?, ?, ?, ?, ?)',
        [userId, 'dave@example.com', 'Dave', null, realWallet, now, now],
      );

      const agents = await service.ensureDefaultAgentForUser(userId);
      expect(agents.length).toBe(1);
      expect(agents[0].agentAddress.toLowerCase()).toBe(realWallet.toLowerCase());
      expect(agents[0].name).toBe('Autonomous Treasury Agent');
    });

    it('should return empty list when user has no walletAddress (zero fallback)', async () => {
      const userId = 'did:privy:unprovisioned_user';
      const now = new Date().toISOString();

      await dbService.run(
        'INSERT INTO "user" (id, email, name, "avatarUrl", "walletAddress", "createdAt", "updatedAt") VALUES (?, ?, ?, ?, ?, ?, ?)',
        [userId, 'empty@example.com', 'Empty', null, null, now, now],
      );

      const agents = await service.ensureDefaultAgentForUser(userId);
      expect(agents).toEqual([]);
    });
  });
});
