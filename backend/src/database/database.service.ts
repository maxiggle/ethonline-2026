import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import * as path from 'path';
import * as fs from 'fs';
const Database = require('better-sqlite3');
import { Pool, PoolClient } from 'pg';
import {
  TreasuryActionRow,
  TreasuryMandateRow,
  DailySpentLedgerRow,
  HumanBindingRow,
} from './database.interface';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private sqliteDb: any = null;
  private pgPool: Pool | null = null;
  private isPostgres = false;

  constructor() {}

  async onModuleInit() {
    await this.initialize();
  }

  async onModuleDestroy() {
    await this.close();
  }

  public async initialize(customSqlitePath?: string): Promise<void> {
    const databaseUrl = process.env.DATABASE_URL;
    const forcePostgres = process.env.DB_CLIENT === 'postgres';

    if (databaseUrl || forcePostgres) {
      try {
        this.pgPool = new Pool({
          connectionString:
            databaseUrl || 'postgresql://chapter2:chapter2_secret@localhost:5432/chapter2_db',
          connectionTimeoutMillis: 3000,
        });
        // Test connection
        const client = await this.pgPool.connect();
        client.release();
        this.isPostgres = true;
        this.logger.log('Connected to PostgreSQL database');
        await this.initPostgresSchema();
        return;
      } catch (err) {
        this.logger.warn(`Failed to connect to PostgreSQL (${err.message}). Falling back to SQLite.`);
        if (this.pgPool) {
          await this.pgPool.end().catch(() => {});
          this.pgPool = null;
        }
      }
    }

    // SQLite mode
    this.isPostgres = false;
    const dbPath =
      customSqlitePath ||
      process.env.SQLITE_DB_PATH ||
      path.resolve(__dirname, '../../../data/chapter2.sqlite');

    if (dbPath !== ':memory:') {
      const dir = path.dirname(dbPath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    }

    this.sqliteDb = new Database(dbPath);
    this.sqliteDb.pragma('journal_mode = WAL');
    this.logger.log(`Initialized SQLite database at: ${dbPath}`);
    this.initSqliteSchema();
  }

  private initSqliteSchema(): void {
    if (!this.sqliteDb) return;

    this.sqliteDb.exec(`
      CREATE TABLE IF NOT EXISTS treasury_actions (
        id TEXT PRIMARY KEY,
        target TEXT NOT NULL,
        value TEXT NOT NULL DEFAULT '0',
        data TEXT NOT NULL DEFAULT '0x',
        token TEXT NOT NULL,
        recipient TEXT NOT NULL,
        amount TEXT NOT NULL,
        agent_address TEXT NOT NULL,
        justification TEXT NOT NULL,
        status TEXT NOT NULL,
        risk_score INTEGER NOT NULL DEFAULT 0,
        requires_human_approval INTEGER NOT NULL DEFAULT 0,
        nonce INTEGER NOT NULL,
        deadline INTEGER NOT NULL,
        signature TEXT,
        tx_hash TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS treasury_mandates (
        chain_id INTEGER NOT NULL,
        safe_address TEXT NOT NULL,
        guard_address TEXT NOT NULL,
        autonomous_agent TEXT NOT NULL,
        human_signer TEXT NOT NULL,
        max_autonomous_amount TEXT NOT NULL,
        daily_autonomous_limit TEXT NOT NULL,
        approved_recipients TEXT NOT NULL,
        approved_tokens TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (chain_id, safe_address)
      );

      CREATE TABLE IF NOT EXISTS daily_spent_ledger (
        day_id INTEGER PRIMARY KEY,
        cumulative_spent TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS human_bindings (
        signer_address TEXT PRIMARY KEY,
        nullifier_hash TEXT NOT NULL,
        bound_at TEXT NOT NULL,
        expires_at TEXT NOT NULL
      );
    `);
  }

  private async initPostgresSchema(): Promise<void> {
    if (!this.pgPool) return;

    await this.pgPool.query(`
      CREATE TABLE IF NOT EXISTS treasury_actions (
        id VARCHAR(128) PRIMARY KEY,
        target VARCHAR(64) NOT NULL,
        value VARCHAR(64) NOT NULL DEFAULT '0',
        data TEXT NOT NULL DEFAULT '0x',
        token VARCHAR(64) NOT NULL,
        recipient VARCHAR(64) NOT NULL,
        amount VARCHAR(64) NOT NULL,
        agent_address VARCHAR(64) NOT NULL,
        justification TEXT NOT NULL,
        status VARCHAR(32) NOT NULL,
        risk_score INTEGER NOT NULL DEFAULT 0,
        requires_human_approval BOOLEAN NOT NULL DEFAULT FALSE,
        nonce INTEGER NOT NULL,
        deadline BIGINT NOT NULL,
        signature TEXT,
        tx_hash VARCHAR(128),
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      CREATE TABLE IF NOT EXISTS treasury_mandates (
        chain_id INTEGER NOT NULL,
        safe_address VARCHAR(64) NOT NULL,
        guard_address VARCHAR(64) NOT NULL,
        autonomous_agent VARCHAR(64) NOT NULL,
        human_signer VARCHAR(64) NOT NULL,
        max_autonomous_amount VARCHAR(64) NOT NULL,
        daily_autonomous_limit VARCHAR(64) NOT NULL,
        approved_recipients JSONB NOT NULL,
        approved_tokens JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL,
        PRIMARY KEY (chain_id, safe_address)
      );

      CREATE TABLE IF NOT EXISTS daily_spent_ledger (
        day_id INTEGER PRIMARY KEY,
        cumulative_spent VARCHAR(64) NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      CREATE TABLE IF NOT EXISTS human_bindings (
        signer_address VARCHAR(64) PRIMARY KEY,
        nullifier_hash VARCHAR(128) NOT NULL,
        bound_at TIMESTAMPTZ NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL
      );
    `);
  }

  public async close(): Promise<void> {
    if (this.sqliteDb) {
      this.sqliteDb.close();
      this.sqliteDb = null;
    }
    if (this.pgPool) {
      await this.pgPool.end();
      this.pgPool = null;
    }
  }

  public getUsingPostgres(): boolean {
    return this.isPostgres;
  }

  // Generic query execution
  public async query<T = any>(sql: string, params: any[] = []): Promise<T[]> {
    if (this.isPostgres && this.pgPool) {
      let pgSql = sql;
      // Convert ? parameters to $1, $2, etc.
      let paramIdx = 1;
      pgSql = pgSql.replace(/\?/g, () => `$${paramIdx++}`);
      const res = await this.pgPool.query(pgSql, params);
      return res.rows as T[];
    } else if (this.sqliteDb) {
      const stmt = this.sqliteDb.prepare(sql);
      if (sql.trim().toUpperCase().startsWith('SELECT')) {
        return stmt.all(...params) as T[];
      } else {
        const info = stmt.run(...params);
        return [info as unknown as T];
      }
    }
    return [];
  }

  public async run(sql: string, params: any[] = []): Promise<any> {
    if (this.isPostgres && this.pgPool) {
      let pgSql = sql;
      let paramIdx = 1;
      pgSql = pgSql.replace(/\?/g, () => `$${paramIdx++}`);
      return await this.pgPool.query(pgSql, params);
    } else if (this.sqliteDb) {
      const stmt = this.sqliteDb.prepare(sql);
      return stmt.run(...params);
    }
  }

  public async getOne<T = any>(sql: string, params: any[] = []): Promise<T | null> {
    const rows = await this.query<T>(sql, params);
    return rows.length > 0 ? rows[0] : null;
  }

  // Synchronous helpers for SQLite (useful for instant synchronous evaluation)
  public querySync<T = any>(sql: string, params: any[] = []): T[] {
    if (this.sqliteDb) {
      const stmt = this.sqliteDb.prepare(sql);
      if (sql.trim().toUpperCase().startsWith('SELECT')) {
        return stmt.all(...params) as T[];
      } else {
        const info = stmt.run(...params);
        return [info as unknown as T];
      }
    }
    return [];
  }

  public getOneSync<T = any>(sql: string, params: any[] = []): T | null {
    const rows = this.querySync<T>(sql, params);
    return rows.length > 0 ? rows[0] : null;
  }

  public runSync(sql: string, params: any[] = []): any {
    if (this.sqliteDb) {
      const stmt = this.sqliteDb.prepare(sql);
      return stmt.run(...params);
    }
  }
}
