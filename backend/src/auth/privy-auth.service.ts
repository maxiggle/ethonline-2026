import {
  Injectable,
  Logger,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { PrivyClient } from '@privy-io/server-auth';
import { DatabaseService } from '../database/database.service';
import { PrivyUserIdentity } from './interfaces/privy-user.interface';

const TEST_TOKEN_PREFIX = 'test_token_';

function isTestEnvironment(): boolean {
  return process.env.NODE_ENV === 'test';
}

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
      this.logger.warn('Privy credentials not set in environment; all bearer tokens will be rejected');
    }
  }

  /**
   * Verifies a Privy bearer token and returns the user's DID and embedded wallet.
   * Test identities (test_token_<did>) are accepted exclusively when NODE_ENV=test.
   */
  async verifyAuthToken(
    token: string,
    metadata?: { email?: string; name?: string; walletAddress?: string },
  ): Promise<PrivyUserIdentity> {
    if (!token) {
      throw new UnauthorizedException('Authentication token is required');
    }

    const cleanToken = token.startsWith('Bearer ') ? token.slice(7) : token;

    if (isTestEnvironment() && cleanToken.startsWith(TEST_TOKEN_PREFIX)) {
      return this.buildTestIdentity(cleanToken, metadata);
    }

    if (!this.privyClient) {
      throw new UnauthorizedException('Privy authentication is not configured on this server');
    }

    try {
      return await this.verifyWithPrivy(this.privyClient, cleanToken, metadata);
    } catch (err: any) {
      this.logger.warn(`Live Privy verification failed: ${err.message}`);
      throw new UnauthorizedException(`Privy token verification failed: ${err.message}`);
    }
  }

  /**
   * Verifies the token signature with Privy and resolves the embedded wallet from Privy itself.
   * Client-supplied wallet addresses are never trusted for live identities.
   */
  private async verifyWithPrivy(
    privyClient: PrivyClient,
    token: string,
    metadata?: { email?: string; name?: string },
  ): Promise<PrivyUserIdentity> {
    const claims = await privyClient.verifyAuthToken(token);
    let user = await privyClient.getUser(claims.userId);
    if (!user) {
      throw new UnauthorizedException(`User ${claims.userId} not found in Privy`);
    }

    const email = user.google?.email || user.email?.address || metadata?.email;
    const name = user.google?.name || metadata?.name;

    let linkedAccounts = (user.linkedAccounts || []) as any[];
    let embeddedWallet = linkedAccounts.find(
      (a) => a.type === 'wallet' && (a.walletClientType === 'privy' || a.connectorType === 'embedded'),
    );
    let walletAddress = embeddedWallet?.address || user.wallet?.address;

    if (!walletAddress) {
      try {
        this.logger.log(`Provisioning embedded EVM wallet for Privy user ${user.id}...`);
        const updatedUser = await privyClient.createWallets({
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
  }

  /**
   * Builds a deterministic identity from a jest-only test token (test_token_<did>).
   */
  private buildTestIdentity(
    token: string,
    metadata?: { email?: string; name?: string; walletAddress?: string },
  ): PrivyUserIdentity {
    const did = token.slice(TEST_TOKEN_PREFIX.length);
    const hexId = Buffer.from(did).toString('hex').padEnd(40, '0').slice(0, 40);
    return {
      id: `did:privy:${did}`,
      email: metadata?.email || `${did}@example.com`,
      name: metadata?.name || `User ${did}`,
      walletAddress: metadata?.walletAddress || `0x${hexId}`,
    };
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
        'SELECT * FROM "user" WHERE email = ? AND "deletedAt" IS NULL',
        [identity.email],
      );
      if (rows.length > 0) {
        existingUser = rows[0];
      }
    }

    // 3. A soft-deleted account signing in again is reactivated as a new user, so it goes through onboarding
    let reactivated = false;
    if (!existingUser) {
      const deletedRows = await this.dbService.query('SELECT * FROM "user" WHERE id = ?', [identity.id]);
      if (deletedRows.length > 0 && deletedRows[0].deletedAt) {
        await this.dbService.run('UPDATE "user" SET "deletedAt" = ?, "updatedAt" = ? WHERE id = ?', [
          null,
          now,
          identity.id,
        ]);
        reactivated = true;
        existingUser = await this.getUser(identity.id);
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
      return { user, isNewUser: reactivated };
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
   * Retrieves an active user from the database by Privy DID.
   */
  async getUser(userId: string): Promise<any> {
    const rows = await this.dbService.query(
      'SELECT * FROM "user" WHERE id = ? AND "deletedAt" IS NULL',
      [userId],
    );
    return rows.length > 0 ? rows[0] : null;
  }

  /**
   * Soft-deletes user account locally and deletes user in Privy Cloud.
   * Preserves historical transaction receipts, execution logs, and mandates for on-chain auditability.
   */
  async deleteUserAccount(userId: string): Promise<{ success: boolean; message: string }> {
    const user = await this.getUser(userId);
    if (!user) {
      const rows = await this.dbService.query('SELECT * FROM "user" WHERE id = ?', [userId]);
      if (rows.length > 0 && rows[0].deletedAt) {
        return { success: true, message: 'Account already deleted' };
      }
      throw new BadRequestException(`User ${userId} does not exist`);
    }

    const now = new Date().toISOString();

    // 1. Soft-delete user in database
    await this.dbService.run(
      'UPDATE "user" SET "deletedAt" = ?, "updatedAt" = ? WHERE id = ?',
      [now, now, userId],
    );

    // 2. Mark bound autonomous agents as INACTIVE
    await this.dbService.run(
      'UPDATE agent SET status = ?, "updatedAt" = ? WHERE "userId" = ?',
      ['INACTIVE', now, userId],
    );

    // 3. Delete from Privy Cloud if PrivyClient is configured
    if (this.privyClient) {
      try {
        this.logger.log(`Deleting user ${userId} from Privy Cloud...`);
        await this.privyClient.deleteUser(userId);
        this.logger.log(`Successfully deleted user ${userId} from Privy Cloud`);
      } catch (err: any) {
        this.logger.warn(`Failed to delete user ${userId} from Privy Cloud: ${err.message}`);
      }
    }

    return {
      success: true,
      message: 'Account deleted successfully',
    };
  }
}
