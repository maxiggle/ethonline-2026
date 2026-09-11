import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { PrivyClient } from '@privy-io/server-auth';
import { DatabaseService } from '../database/database.service';
import { PrivyUserIdentity } from './interfaces/privy-user.interface';

@Injectable()
export class PrivyAuthService {
  private readonly logger = new Logger(PrivyAuthService.name);
  private privyClient: PrivyClient | null = null;

  constructor(private readonly dbService: DatabaseService) {
    const appId = process.env.PRIVY_APP_ID;
    const appSecret = process.env.PRIVY_APP_SECRET;

    if (appId && appSecret) {
      try {
        this.privyClient = new PrivyClient(appId, appSecret);
        this.logger.log('PrivyClient initialized with live App ID');
      } catch (err: any) {
        this.logger.warn(`Failed to initialize PrivyClient: ${err.message}`);
      }
    } else {
      this.logger.log('Privy credentials not set in environment; running in development test verification mode');
    }
  }

  /**
   * Verifies a Privy bearer token and returns the user's DID and embedded wallet.
   */
  async verifyAuthToken(token: string): Promise<PrivyUserIdentity> {
    if (!token) {
      throw new UnauthorizedException('Authentication token is required');
    }

    // Clean "Bearer " prefix if passed directly
    const cleanToken = token.startsWith('Bearer ') ? token.slice(7) : token;

    // 1. Live Privy verification if client is configured
    if (this.privyClient) {
      try {
        const claims = await this.privyClient.verifyAuthToken(cleanToken);
        const user = await this.privyClient.getUser(claims.userId);

        const email = user.google?.email || user.email?.address;
        const name = user.google?.name;
        // Embedded wallet address created by Privy
        const walletAddress = user.wallet?.address;

        return {
          id: user.id,
          email,
          name,
          walletAddress,
        };
      } catch (err: any) {
        this.logger.warn(`Live Privy verification failed: ${err.message}`);
        // If not in development, rethrow
        if (process.env.NODE_ENV === 'production') {
          throw new UnauthorizedException('Invalid Privy authentication token');
        }
      }
    }

    // 2. Development / Test token verification
    return this.verifyTestToken(cleanToken);
  }

  /**
   * Verifies test tokens for integration testing and offline development.
   * Format: test_token_<did> or Base64 JSON payload
   */
  private verifyTestToken(token: string): PrivyUserIdentity {
    if (token.startsWith('test_token_')) {
      const did = token.replace('test_token_', '');
      return {
        id: `did:privy:${did}`,
        email: `${did}@example.com`,
        name: `User ${did}`,
        walletAddress: '0x1234567890123456789012345678901234567890',
      };
    }

    // Attempt decoding if Base64 encoded JSON token
    try {
      const parts = token.split('.');
      if (parts.length >= 2) {
        const payloadStr = Buffer.from(parts[1], 'base64').toString('utf-8');
        const payload = JSON.parse(payloadStr);
        if (payload.sub || payload.userId) {
          return {
            id: payload.sub || payload.userId,
            email: payload.email,
            name: payload.name,
            walletAddress: payload.walletAddress || '0x1234567890123456789012345678901234567890',
          };
        }
      }
    } catch {}

    throw new UnauthorizedException('Invalid or expired authentication token');
  }

  /**
   * Synchronizes authenticated Privy user identity with PostgreSQL database.
   */
  async syncUser(identity: PrivyUserIdentity): Promise<any> {
    const now = new Date().toISOString();

    const sql = `
      INSERT INTO "user" (id, email, name, "avatarUrl", "walletAddress", "createdAt", "updatedAt")
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        "avatarUrl" = EXCLUDED."avatarUrl",
        "walletAddress" = EXCLUDED."walletAddress",
        "updatedAt" = EXCLUDED."updatedAt"
    `;

    await this.dbService.run(sql, [
      identity.id,
      identity.email || null,
      identity.name || null,
      identity.avatarUrl || null,
      identity.walletAddress || null,
      now,
      now,
    ]);

    return await this.getUser(identity.id);
  }

  /**
   * Retrieves a user from the database by Privy DID.
   */
  async getUser(userId: string): Promise<any> {
    const rows = await this.dbService.query(
      'SELECT * FROM "user" WHERE id = ?',
      [userId],
    );
    return rows.length > 0 ? rows[0] : null;
  }
}
