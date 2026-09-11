import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { PrivyAuthService } from './privy-auth.service';
import { DatabaseModule } from '../database/database.module';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: PrivyAuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule],
      controllers: [AuthController],
      providers: [PrivyAuthService],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    authService = module.get<PrivyAuthService>(PrivyAuthService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('POST /auth/login', () => {
    it('should authenticate user with valid token, sync profile, and return embedded wallet', async () => {
      const response = await controller.login({ authToken: 'test_token_sammy99' });

      expect(response.success).toBe(true);
      expect(response.user).toBeDefined();
      expect(response.user.id).toBe('did:privy:sammy99');
      expect(response.user.email).toBe('sammy99@example.com');
      expect(response.user.walletAddress).toBeDefined();
    });
  });

  describe('GET /auth/me', () => {
    it('should return user profile from request context', async () => {
      // First login/sync user
      await controller.login({ authToken: 'test_token_sammy99' });

      const mockReq = {
        user: {
          id: 'did:privy:sammy99',
          email: 'sammy99@example.com',
          walletAddress: '0x1234567890123456789012345678901234567890',
        },
      };

      const response = await controller.getProfile(mockReq);
      expect(response.success).toBe(true);
      expect(response.user.id).toBe('did:privy:sammy99');
    });
  });
});
