import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { Wallet } from 'ethers';
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

    it('should reject callers that do not own an active agent', async () => {
      const userId = 'did:privy:erin_test';
      const agentAddress = '0x5555555555555555555555555555555555555555';
      await service.bindAgent(userId, {
        agentAddress,
        name: 'Erin Agent',
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        chainId: 84532,
      });

      await expect(service.assertAgentOwnership(userId, agentAddress)).resolves.toBeUndefined();
      await expect(
        service.assertAgentOwnership('did:privy:mallory', agentAddress),
      ).rejects.toThrow('is not an active agent owned by the authenticated user');
      await expect(
        service.assertAgentOwnership(userId, '0x6666666666666666666666666666666666666666'),
      ).rejects.toThrow('is not an active agent owned by the authenticated user');
    });

    it('reactivates a deactivated agent instead of creating a duplicate', async () => {
      const userId = `did:privy:rebind_${Date.now()}`;
      const agentAddress = Wallet.createRandom().address;
      const dto: BindAgentDto = {
        agentAddress,
        name: 'Rebound Agent',
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        chainId: 84532,
      };
      const first = await service.bindAgent(userId, dto);
      await dbService.run('UPDATE agent SET status = ?, "updatedAt" = ? WHERE "userId" = ?', [
        'INACTIVE',
        new Date().toISOString(),
        userId,
      ]);

      const rebound = await service.bindAgent(userId, dto);

      expect(rebound.id).toBe(first.id);
      expect(rebound.status).toBe('ACTIVE');
      const rows = await dbService.query('SELECT * FROM agent WHERE "agentAddress" = ?', [agentAddress]);
      expect(rows.length).toBe(1);
      expect((await service.getAgentByAddress(agentAddress))?.status).toBe('ACTIVE');
    });

    it('refuses to bind an address that is actively bound to another account', async () => {
      const agentAddress = Wallet.createRandom().address;
      const dto: BindAgentDto = {
        agentAddress,
        name: 'Contested Agent',
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        chainId: 84532,
      };
      await service.bindAgent(`did:privy:owner_${Date.now()}`, dto);

      await expect(service.bindAgent(`did:privy:other_${Date.now()}`, dto)).rejects.toThrow(ConflictException);
    });

    it('prefers the active row when an address has older inactive duplicates', async () => {
      const userId = `did:privy:dupes_${Date.now()}`;
      const agentAddress = Wallet.createRandom().address;
      const now = new Date().toISOString();
      const insertSql =
        'INSERT INTO agent (id, "userId", "agentAddress", name, purpose, "safeAddress", "guardAddress", "chainId", status, "createdAt", "updatedAt") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
      const safe = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
      const guard = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
      await dbService.run(insertSql, [`agent_old_${Date.now()}`, 'did:privy:previous_owner', agentAddress, 'Old', null, safe, guard, 84532, 'INACTIVE', now, now]);
      await dbService.run(insertSql, [`agent_new_${Date.now()}`, userId, agentAddress, 'New', null, safe, guard, 84532, 'ACTIVE', now, now]);

      const agent = await service.getAgentByAddress(agentAddress);

      expect(agent?.status).toBe('ACTIVE');
      expect(agent?.userId).toBe(userId);
    });
  });
});
