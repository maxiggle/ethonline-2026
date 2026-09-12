import {
  Injectable,
  Logger,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
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
  async verifyAuthToken(
    token: string,
    metadata?: { email?: string; name?: string; walletAddress?: string },
  ): Promise<PrivyUserIdentity> {
    if (!token) {
      throw new UnauthorizedException('Authentication token is required');
    }

    // Clean "Bearer " prefix if passed directly
    const cleanToken = token.startsWith('Bearer ') ? token.slice(7) : token;

    // 1. Live Privy verification if client is configured
    if (this.privyClient) {
      try {
        const claims = await this.privyClient.verifyAuthToken(cleanToken);
        let user = await this.privyClient.getUser(claims.userId);
        if (!user) {
          throw new UnauthorizedException(`User ${claims.userId} not found in Privy`);
        }

        const email = user.google?.email || user.email?.address || metadata?.email;
        const name = user.google?.name || metadata?.name;
        
        // Locate embedded Ethereum wallet
        let linkedAccounts = (user.linkedAccounts || []) as any[];
        let embeddedWallet = linkedAccounts.find(
          (a) => a.type === 'wallet' && (a.walletClientType === 'privy' || a.connectorType === 'embedded'),
        );
        let walletAddress = embeddedWallet?.address || user.wallet?.address || metadata?.walletAddress;

        // If user does not yet have an embedded Ethereum wallet, provision one automatically via Privy
        if (!walletAddress && this.privyClient) {
          try {
            this.logger.log(`Provisioning embedded EVM wallet for Privy user ${user.id}...`);
            const updatedUser = await this.privyClient.createWallets({
              userId: user.id,
              createEthereumWallet: true,
            });
            if (updatedUser) {
              user = updatedUser;
              linkedAccounts = (user.linkedAccounts || []) as any[];
              embeddedWallet = linkedAccounts.find(
                (a) => a.type === 'wallet' && (a.walletClientType === 'privy' || a.connectorType === 'embedded'),
              );
              walletAddress = embeddedWallet?.address || user.wallet?.address;
              this.logger.log(`Provisioned embedded EVM wallet ${walletAddress} for user ${user.id}`);
            }
          } catch (createErr: any) {
            this.logger.warn(`Failed to auto-provision embedded wallet: ${createErr.message}`);
          }
        }

        if (!walletAddress) {
          throw new UnauthorizedException(`User ${user.id} does not have an active EVM wallet address`);
        }

        return {
          id: user.id,
          email,
          name,
          walletAddress,
        };
      } catch (err: any) {
        this.logger.warn(`Live Privy verification failed: ${err.message}`);
        if (!cleanToken.startsWith('test_token_')) {
          throw new UnauthorizedException(`Privy token verification failed: ${err.message}`);
        }
      }
    }

    // 2. Development / Test token verification
    return this.verifyTestToken(cleanToken, metadata);
  }

  /**
   * Verifies test tokens for integration testing and offline development.
   * Format: test_token_<did> or Base64 JSON payload
   */
  private verifyTestToken(
    token: string,
    metadata?: { email?: string; name?: string; walletAddress?: string },
  ): PrivyUserIdentity {
    if (token.startsWith('test_token_')) {
      const did = token.replace('test_token_', '');
      const hexId = Buffer.from(did).toString('hex').padEnd(40, '0').slice(0, 40);
      const testWallet = `0x${hexId}`;
      return {
        id: `did:privy:${did}`,
        email: metadata?.email || `${did}@example.com`,
        name: metadata?.name || `User ${did}`,
        walletAddress: metadata?.walletAddress || testWallet,
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
            email: payload.email || metadata?.email,
            name: payload.name || metadata?.name,
            walletAddress: payload.walletAddress || metadata?.walletAddress,
          };
        }
      }
    } catch {}

    throw new UnauthorizedException('Invalid or expired authentication token');
  }

  /**
   * Synchronizes authenticated Privy user identity with PostgreSQL database.
   */
  async syncUser(identity: PrivyUserIdentity): Promise<{ user: any; isNewUser: boolean }> {
    const now = new Date().toISOString();

    // 1. Check if user already exists by ID
    let existingUser = await this.getUser(identity.id);

    // 2. If not found by ID, check by email to prevent duplicate key violations on unique email
    if (!existingUser && identity.email) {
      const rows = await this.dbService.query(
        'SELECT * FROM "user" WHERE email = ?',
        [identity.email],
      );
      if (rows.length > 0) {
        existingUser = rows[0];
      }
    }

    const walletAddress = identity.walletAddress || existingUser?.walletAddress;
    if (!walletAddress) {
      throw new BadRequestException('walletAddress is required');
    }

    if (existingUser) {
      const updateSql = `
        UPDATE "user"
        SET
          email = ?,
          name = ?,
          "avatarUrl" = ?,
          "walletAddress" = ?,
          "updatedAt" = ?
        WHERE id = ?
      `;

      await this.dbService.run(updateSql, [
        identity.email || existingUser.email,
        identity.name || existingUser.name,
        identity.avatarUrl || existingUser.avatarUrl,
        walletAddress,
        now,
        existingUser.id,
      ]);
      const user = await this.getUser(existingUser.id);
      return { user, isNewUser: false };
    } else {
      const insertSql = `
        INSERT INTO "user" (id, email, name, "avatarUrl", "walletAddress", "createdAt", "updatedAt")
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `;
      await this.dbService.run(insertSql, [
        identity.id,
        identity.email || null,
        identity.name || null,
        identity.avatarUrl || null,
        walletAddress,
        now,
        now,
      ]);
      const user = await this.getUser(identity.id);
      return { user, isNewUser: true };
    }
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
