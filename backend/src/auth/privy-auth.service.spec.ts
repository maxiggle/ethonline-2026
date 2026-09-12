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
});
