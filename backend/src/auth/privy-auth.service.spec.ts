import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { PrivyAuthService } from './privy-auth.service';
import { DatabaseModule } from '../database/database.module';
import { DatabaseService } from '../database/database.service';

describe('PrivyAuthService', () => {
  let service: PrivyAuthService;
  let dbService: DatabaseService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule],
      providers: [PrivyAuthService],
    }).compile();

    service = module.get<PrivyAuthService>(PrivyAuthService);
    dbService = module.get<DatabaseService>(DatabaseService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('verifyAuthToken', () => {
    it('should successfully verify test token and return user identity with embedded wallet', async () => {
      const token = 'test_token_alice123';
      const identity = await service.verifyAuthToken(token);

      expect(identity).toBeDefined();
      expect(identity.id).toBe('did:privy:alice123');
      expect(identity.email).toBe('alice123@example.com');
      expect(identity.walletAddress).toBeDefined();
      expect(identity.walletAddress).toMatch(/^0x[a-fA-F0-9]{40}$/);
    });

    it('should accept Bearer prefix in token', async () => {
      const token = 'Bearer test_token_bob456';
      const identity = await service.verifyAuthToken(token);

      expect(identity.id).toBe('did:privy:bob456');
      expect(identity.email).toBe('bob456@example.com');
    });

    it('should throw UnauthorizedException when token is empty', async () => {
      await expect(service.verifyAuthToken('')).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException when token is invalid', async () => {
      await expect(service.verifyAuthToken('invalid_token')).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('syncUser & getUser', () => {
    it('should persist user identity to database and retrieve it by DID', async () => {
      const identity = {
        id: 'did:privy:cluser789',
        email: 'user789@gmail.com',
        name: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
        walletAddress: '0x1234567890123456789012345678901234567890',
      };

      await service.syncUser(identity);
      const retrieved = await service.getUser('did:privy:cluser789');

      expect(retrieved).toBeDefined();
      expect(retrieved.id).toBe(identity.id);
      expect(retrieved.email).toBe(identity.email);
      expect(retrieved.name).toBe(identity.name);
      expect(retrieved.walletAddress).toBe(identity.walletAddress);
    });
  });

  describe('deleteUserAccount', () => {
    it('should soft-delete user in database and mark bound agents inactive', async () => {
      const identity = {
        id: 'did:privy:del_user_1',
        email: 'del1@example.com',
        name: 'Del User',
        walletAddress: '0x2222222222222222222222222222222222222222',
      };

      await service.syncUser(identity);
      expect(await service.getUser(identity.id)).toBeDefined();

      // Create an agent bound to this user
      const now = new Date().toISOString();
      await dbService.run(
        'INSERT INTO agent (id, "userId", "agentAddress", name, purpose, "safeAddress", "guardAddress", "chainId", status, "createdAt", "updatedAt") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'agent_del_1',
          identity.id,
          '0x2222222222222222222222222222222222222222',
          'Autonomous Agent',
          'Treasury operations',
          '0x4f712dd78cb1a504c69cb4f68b82fddb6b3b1df6',
          '0x9b6023d1b6d3b076c8d999ba406ae486750ce7d3',
          84532,
          'ACTIVE',
          now,
          now,
        ],
      );

      const res = await service.deleteUserAccount(identity.id);
      expect(res.success).toBe(true);

      // Verify user is no longer retrieved via active getUser
      const userAfter = await service.getUser(identity.id);
      expect(userAfter).toBeNull();

      // Verify agent status updated to INACTIVE
      const agents = await dbService.query(
        'SELECT * FROM agent WHERE "userId" = ?',
        [identity.id],
      );
      expect(agents.length).toBe(1);
      expect(agents[0].status).toBe('INACTIVE');
    });

    it('should throw BadRequestException when deleting non-existent or already deleted user', async () => {
      await expect(
        service.deleteUserAccount('did:privy:non_existent_user'),
      ).rejects.toThrow();
    });
  });
});
