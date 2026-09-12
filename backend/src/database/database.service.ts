import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import * as path from 'path';
import * as fs from 'fs';
import { Pool } from 'pg';
import {
  TreasuryActionRow,
  TreasuryMandateRow,
  DailySpentLedgerRow,
  HumanBindingRow,
} from './database.interface';

interface InMemoryState {
  users: Map<string, any>;
  agents: Map<string, any>;
  treasuryActions: Map<string, TreasuryActionRow>;
  treasuryMandates: Map<string, TreasuryMandateRow>;
  dailySpentLedger: Map<number, DailySpentLedgerRow>;
  humanBindings: Map<string, HumanBindingRow>;
}

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pgPool: Pool | null = null;
  private isPostgres = false;
  private filePath: string | null = null;

  // High-performance synchronized in-memory tables for zero-latency hot paths
  private state: InMemoryState = {
    users: new Map(),
    agents: new Map(),
    treasuryActions: new Map(),
    treasuryMandates: new Map(),
    dailySpentLedger: new Map(),
    humanBindings: new Map(),
  };

  constructor() {}

  async onModuleInit() {
    await this.initialize();
  }

  async onModuleDestroy() {
    await this.close();
  }

  public async initialize(customPathOrUrl?: string): Promise<void> {
    const databaseUrl =
      process.env.DATABASE_URL ||
      'postgresql://chapter2:chapter2_secret@localhost:5433/chapter2_db?schema=public';

    // Check if custom path is a file path (for persistence unit tests without external DB)
    if (
      customPathOrUrl &&
      customPathOrUrl !== ':memory:' &&
      !customPathOrUrl.startsWith('postgres')
    ) {
      this.filePath = customPathOrUrl;
      this.loadFromFile();
      this.logger.log(`Initialized file-backed persistence at: ${this.filePath}`);
      return;
    }

    // Connect to PostgreSQL
    try {
      this.pgPool = new Pool({
        connectionString: databaseUrl,
        connectionTimeoutMillis: 3000,
      });
      const client = await this.pgPool.connect();
      client.release();
      this.isPostgres = true;
      this.logger.log('Connected to PostgreSQL database');
      await this.initPostgresSchema();
      await this.loadFromPostgres();
      return;
    } catch (err: any) {
      this.logger.warn(
        `Could not connect to PostgreSQL (${err.message}). Using synchronized in-memory persistence.`,
      );
      if (this.pgPool) {
        await this.pgPool.end().catch(() => {});
        this.pgPool = null;
      }
      this.isPostgres = false;
    }
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

      CREATE TABLE IF NOT EXISTS "user" (
        id VARCHAR(128) PRIMARY KEY,
        email VARCHAR(128) UNIQUE,
        name VARCHAR(128),
        "avatarUrl" TEXT,
        "walletAddress" VARCHAR(64),
        "createdAt" TIMESTAMPTZ NOT NULL,
        "updatedAt" TIMESTAMPTZ NOT NULL
      );

      CREATE TABLE IF NOT EXISTS agent (
        id VARCHAR(128) PRIMARY KEY,
        "userId" VARCHAR(128) NOT NULL,
        "agentAddress" VARCHAR(64) NOT NULL,
        name VARCHAR(128) NOT NULL,
        purpose TEXT,
        "safeAddress" VARCHAR(64) NOT NULL,
        "guardAddress" VARCHAR(64) NOT NULL,
        "chainId" INTEGER NOT NULL DEFAULT 84532,
        status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
        "createdAt" TIMESTAMPTZ NOT NULL,
        "updatedAt" TIMESTAMPTZ NOT NULL
      );
    `);
  }

  private async loadFromPostgres(): Promise<void> {
    if (!this.pgPool) return;

    try {
      const usersRes = await this.pgPool.query('SELECT * FROM "user"');
      for (const row of usersRes.rows) {
        this.state.users.set(row.id, {
          id: row.id,
          email: row.email,
          name: row.name,
          avatarUrl: row.avatarUrl || row.avatar_url,
          walletAddress: row.walletAddress || row.wallet_address,
          createdAt: new Date(row.createdAt || row.created_at).toISOString(),
          updatedAt: new Date(row.updatedAt || row.updated_at).toISOString(),
        });
      }

      const agentsRes = await this.pgPool.query('SELECT * FROM agent');
      for (const row of agentsRes.rows) {
        this.state.agents.set(row.id, {
          id: row.id,
          userId: row.userId || row.user_id,
          agentAddress: row.agentAddress || row.agent_address,
          name: row.name,
          purpose: row.purpose,
          safeAddress: row.safeAddress || row.safe_address,
          guardAddress: row.guardAddress || row.guard_address,
          chainId: Number(row.chainId || row.chain_id || 84532),
          status: row.status || 'ACTIVE',
          createdAt: new Date(row.createdAt || row.created_at).toISOString(),
          updatedAt: new Date(row.updatedAt || row.updated_at).toISOString(),
        });
      }

      const actionsRes = await this.pgPool.query<TreasuryActionRow>(
        'SELECT * FROM treasury_actions ORDER BY nonce ASC',
      );
      for (const row of actionsRes.rows) {
        this.state.treasuryActions.set(row.id, {
          ...row,
          created_at: new Date(row.created_at).toISOString(),
          updated_at: new Date(row.updated_at).toISOString(),
        });
      }

      const mandatesRes = await this.pgPool.query<TreasuryMandateRow>(
        'SELECT * FROM treasury_mandates',
      );
      for (const row of mandatesRes.rows) {
        const key = `${row.chain_id}_${row.safe_address.toLowerCase()}`;
        this.state.treasuryMandates.set(key, {
          ...row,
          approved_recipients:
            typeof row.approved_recipients === 'string'
              ? row.approved_recipients
              : JSON.stringify(row.approved_recipients),
          approved_tokens:
            typeof row.approved_tokens === 'string'
              ? row.approved_tokens
              : JSON.stringify(row.approved_tokens),
          updated_at: new Date(row.updated_at).toISOString(),
        });
      }

      const ledgerRes = await this.pgPool.query<DailySpentLedgerRow>(
        'SELECT * FROM daily_spent_ledger',
      );
      for (const row of ledgerRes.rows) {
        this.state.dailySpentLedger.set(Number(row.day_id), {
          ...row,
          day_id: Number(row.day_id),
          updated_at: new Date(row.updated_at).toISOString(),
        });
      }

      const bindingsRes = await this.pgPool.query<HumanBindingRow>(
        'SELECT * FROM human_bindings',
      );
      for (const row of bindingsRes.rows) {
        this.state.humanBindings.set(row.signer_address.toLowerCase(), {
          ...row,
          bound_at: new Date(row.bound_at).toISOString(),
          expires_at: new Date(row.expires_at).toISOString(),
        });
      }
    } catch (err: any) {
      this.logger.error(`Error loading state from PostgreSQL: ${err.message}`);
    }
  }

  private loadFromFile(): void {
    if (!this.filePath || !fs.existsSync(this.filePath)) return;

    try {
      const data = JSON.parse(fs.readFileSync(this.filePath, 'utf-8'));
      if (data.treasuryActions) {
        this.state.treasuryActions = new Map(Object.entries(data.treasuryActions));
      }
      if (data.treasuryMandates) {
        this.state.treasuryMandates = new Map(Object.entries(data.treasuryMandates));
      }
      if (data.dailySpentLedger) {
        this.state.dailySpentLedger = new Map(
          Object.entries(data.dailySpentLedger).map(([k, v]) => [Number(k), v as DailySpentLedgerRow]),
        );
      }
      if (data.humanBindings) {
        this.state.humanBindings = new Map(Object.entries(data.humanBindings));
      }
    } catch (err: any) {
      this.logger.error(`Error reading persistence file: ${err.message}`);
    }
  }

  private saveToFile(): void {
    if (!this.filePath) return;

    try {
      const dir = path.dirname(this.filePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      const data = {
        treasuryActions: Object.fromEntries(this.state.treasuryActions),
        treasuryMandates: Object.fromEntries(this.state.treasuryMandates),
        dailySpentLedger: Object.fromEntries(this.state.dailySpentLedger),
        humanBindings: Object.fromEntries(this.state.humanBindings),
      };
      fs.writeFileSync(this.filePath, JSON.stringify(data, null, 2), 'utf-8');
    } catch (err: any) {
      this.logger.error(`Error saving persistence file: ${err.message}`);
    }
  }

  public async close(): Promise<void> {
    if (this.pgPool) {
      await this.pgPool.end();
      this.pgPool = null;
    }
    this.isPostgres = false;
  }

  public getUsingPostgres(): boolean {
    return this.isPostgres;
  }

  // Generic query execution
  public async query<T = any>(sql: string, params: any[] = []): Promise<T[]> {
    if (this.isPostgres && this.pgPool) {
      try {
        let pgSql = sql;
        let paramIdx = 1;
        pgSql = pgSql.replace(/\?/g, () => `$${paramIdx++}`);
        const res = await this.pgPool.query(pgSql, params);
        return res.rows as T[];
      } catch (err: any) {
        this.logger.warn(`PostgreSQL query error, falling back to cache: ${err.message}`);
      }
    }
    return this.querySync<T>(sql, params);
  }

  public async run(sql: string, params: any[] = []): Promise<any> {
    const result = this.runSync(sql, params);
    if (this.isPostgres && this.pgPool) {
      try {
        let pgSql = this.toPostgresSql(sql);
        let paramIdx = 1;
        pgSql = pgSql.replace(/\?/g, () => `$${paramIdx++}`);
        await this.pgPool.query(pgSql, params);
      } catch (err: any) {
        this.logger.warn(`PostgreSQL write error: ${err.message}`);
      }
    }
    return result;
  }

  public async getOne<T = any>(sql: string, params: any[] = []): Promise<T | null> {
    const rows = await this.query<T>(sql, params);
    return rows.length > 0 ? rows[0] : null;
  }

  // Synchronous execution against fast in-memory store
  public querySync<T = any>(sql: string, params: any[] = []): T[] {
    const s = sql.trim().toUpperCase();

    if (s.includes('FROM TREASURY_ACTIONS')) {
      if (s.includes('WHERE ID =')) {
        const id = params[0];
        const item = this.state.treasuryActions.get(id);
        return item ? ([item] as unknown as T[]) : [];
      }
      const actions = Array.from(this.state.treasuryActions.values());
      actions.sort((a, b) => Number(a.nonce) - Number(b.nonce));
      return actions as unknown as T[];
    }

    if (s.includes('FROM TREASURY_MANDATES')) {
      if (s.includes('WHERE CHAIN_ID =') && s.includes('SAFE_ADDRESS =')) {
        const chainId = params[0];
        const safeAddress = String(params[1]).toLowerCase();
        const key = `${chainId}_${safeAddress}`;
        const mandate = this.state.treasuryMandates.get(key);
        return mandate ? ([mandate] as unknown as T[]) : [];
      }
      return Array.from(this.state.treasuryMandates.values()) as unknown as T[];
    }

    if (s.includes('FROM DAILY_SPENT_LEDGER')) {
      if (s.includes('WHERE DAY_ID =')) {
        const dayId = Number(params[0]);
        const item = this.state.dailySpentLedger.get(dayId);
        return item ? ([item] as unknown as T[]) : [];
      }
      return Array.from(this.state.dailySpentLedger.values()) as unknown as T[];
    }

    if (s.includes('FROM HUMAN_BINDINGS')) {
      if (s.includes('WHERE SIGNER_ADDRESS =')) {
        const signer = String(params[0]).toLowerCase();
        const item = this.state.humanBindings.get(signer);
        return item ? ([item] as unknown as T[]) : [];
      }
      if (s.includes('WHERE NULLIFIER_HASH =')) {
        const nullifier = String(params[0]);
        for (const item of this.state.humanBindings.values()) {
          if (item.nullifier_hash === nullifier) {
            return [item] as unknown as T[];
          }
        }
        return [];
      }
      return Array.from(this.state.humanBindings.values()) as unknown as T[];
    }

    if (s.includes('FROM "USER"') || s.includes('FROM USER ') || s.includes('FROM USERS')) {
      if (s.includes('WHERE ID =')) {
        const id = params[0];
        const item = this.state.users.get(id);
        return item ? ([item] as unknown as T[]) : [];
      }
      return Array.from(this.state.users.values()) as unknown as T[];
    }

    if (s.includes('FROM AGENT') || s.includes('FROM "AGENT"') || s.includes('FROM AGENTS')) {
      if (s.includes('WHERE "USERID" =') || s.includes('WHERE USERID =') || s.includes('WHERE USER_ID =')) {
        const userId = params[0];
        return Array.from(this.state.agents.values()).filter((a) => a.userId === userId) as unknown as T[];
      }
      if (s.includes('WHERE "AGENTADDRESS" =') || s.includes('WHERE AGENT_ADDRESS =')) {
        const addr = String(params[0]).toLowerCase();
        return Array.from(this.state.agents.values()).filter(
          (a) => a.agentAddress.toLowerCase() === addr,
        ) as unknown as T[];
      }
      if (s.includes('WHERE ID =')) {
        const id = params[0];
        const item = this.state.agents.get(id);
        return item ? ([item] as unknown as T[]) : [];
      }
      return Array.from(this.state.agents.values()) as unknown as T[];
    }

    return [];
  }

  public getOneSync<T = any>(sql: string, params: any[] = []): T | null {
    const rows = this.querySync<T>(sql, params);
    return rows.length > 0 ? rows[0] : null;
  }

  public runSync(sql: string, params: any[] = []): any {
    const s = sql.trim().toUpperCase();

    // 1. Treasury Actions
    if (s.startsWith('INSERT INTO TREASURY_ACTIONS')) {
      const [
        id, target, value, data, token, recipient, amount, agent_address,
        justification, status, risk_score, requires_human_approval, nonce,
        deadline, signature, tx_hash, created_at, updated_at,
      ] = params;

      const row: TreasuryActionRow = {
        id, target, value, data, token, recipient, amount, agent_address,
        justification, status, risk_score: Number(risk_score),
        requires_human_approval: Boolean(requires_human_approval),
        nonce: Number(nonce), deadline: Number(deadline),
        signature: signature || null, tx_hash: tx_hash || null,
        created_at: String(created_at), updated_at: String(updated_at),
      };
      this.state.treasuryActions.set(id, row);
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    if (s.startsWith('UPDATE TREASURY_ACTIONS')) {
      // SET status = ?, signature = ?, tx_hash = ?, updated_at = ? WHERE id = ?
      const [status, signature, tx_hash, updated_at, id] = params;
      const existing = this.state.treasuryActions.get(id);
      if (existing) {
        existing.status = status;
        if (signature) existing.signature = signature;
        if (tx_hash) existing.tx_hash = tx_hash;
        existing.updated_at = updated_at;
        this.saveToFile();
        this.asyncWriteToPostgres(sql, params);
      }
      return { changes: 1 };
    }

    if (s.startsWith('DELETE FROM TREASURY_ACTIONS')) {
      this.state.treasuryActions.clear();
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    // 2. Treasury Mandates
    if (s.includes('INTO TREASURY_MANDATES')) {
      const [
        chain_id, safe_address, guard_address, autonomous_agent, human_signer,
        max_autonomous_amount, daily_autonomous_limit, approved_recipients,
        approved_tokens, updated_at,
      ] = params;

      const row: TreasuryMandateRow = {
        chain_id: Number(chain_id),
        safe_address,
        guard_address,
        autonomous_agent,
        human_signer,
        max_autonomous_amount: String(max_autonomous_amount),
        daily_autonomous_limit: String(daily_autonomous_limit),
        approved_recipients: String(approved_recipients),
        approved_tokens: String(approved_tokens),
        updated_at: String(updated_at),
      };
      const key = `${chain_id}_${safe_address.toLowerCase()}`;
      this.state.treasuryMandates.set(key, row);
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    // 3. Daily Spent Ledger
    if (s.includes('INTO DAILY_SPENT_LEDGER')) {
      const [day_id, cumulative_spent, updated_at] = params;
      const row: DailySpentLedgerRow = {
        day_id: Number(day_id),
        cumulative_spent: String(cumulative_spent),
        updated_at: String(updated_at),
      };
      this.state.dailySpentLedger.set(Number(day_id), row);
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    // 4. Human Bindings
    if (s.includes('INTO HUMAN_BINDINGS')) {
      const [signer_address, nullifier_hash, bound_at, expires_at] = params;
      const row: HumanBindingRow = {
        signer_address,
        nullifier_hash,
        bound_at: String(bound_at),
        expires_at: String(expires_at),
      };
      this.state.humanBindings.set(signer_address.toLowerCase(), row);
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    if (s.startsWith('DELETE FROM HUMAN_BINDINGS')) {
      const signer = String(params[0]).toLowerCase();
      this.state.humanBindings.delete(signer);
      return { changes: 1 };
    }

    // 5. User Identity
    if (s.includes('INTO "USER"') || s.includes('INTO USER ') || s.includes('INTO USERS')) {
      const [id, email, name, avatarUrl, walletAddress, createdAt, updatedAt] = params;
      const user = {
        id,
        email: email || null,
        name: name || null,
        avatarUrl: avatarUrl || null,
        walletAddress: walletAddress || null,
        createdAt: String(createdAt),
        updatedAt: String(updatedAt),
      };
      this.state.users.set(id, user);
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    // 6. Agent Management
    if (s.includes('INTO AGENT') || s.includes('INTO "AGENT"') || s.includes('INTO AGENTS')) {
      const [id, userId, agentAddress, name, purpose, safeAddress, guardAddress, chainId, status, createdAt, updatedAt] = params;
      const agent = {
        id,
        userId,
        agentAddress,
        name,
        purpose: purpose || null,
        safeAddress,
        guardAddress,
        chainId: Number(chainId || 84532),
        status: status || 'ACTIVE',
        createdAt: String(createdAt),
        updatedAt: String(updatedAt),
      };
      this.state.agents.set(id, agent);
      this.saveToFile();
      this.asyncWriteToPostgres(sql, params);
      return { changes: 1 };
    }

    return { changes: 0 };
  }

  private toPostgresSql(sql: string): string {
    let pgSql = sql;
    // Replace SQLite "INSERT OR REPLACE INTO" with PostgreSQL "INSERT INTO ... ON CONFLICT DO UPDATE"
    if (pgSql.includes('INSERT OR REPLACE INTO treasury_mandates')) {
      pgSql = `
        INSERT INTO treasury_mandates (
          chain_id, safe_address, guard_address, autonomous_agent, human_signer,
          max_autonomous_amount, daily_autonomous_limit, approved_recipients, approved_tokens, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (chain_id, safe_address) DO UPDATE SET
          guard_address = EXCLUDED.guard_address,
          autonomous_agent = EXCLUDED.autonomous_agent,
          human_signer = EXCLUDED.human_signer,
          max_autonomous_amount = EXCLUDED.max_autonomous_amount,
          daily_autonomous_limit = EXCLUDED.daily_autonomous_limit,
          approved_recipients = EXCLUDED.approved_recipients,
          approved_tokens = EXCLUDED.approved_tokens,
          updated_at = EXCLUDED.updated_at
      `;
    } else if (pgSql.includes('INSERT OR REPLACE INTO daily_spent_ledger')) {
      pgSql = `
        INSERT INTO daily_spent_ledger (day_id, cumulative_spent, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT (day_id) DO UPDATE SET
          cumulative_spent = EXCLUDED.cumulative_spent,
          updated_at = EXCLUDED.updated_at
      `;
    } else if (pgSql.includes('INSERT OR REPLACE INTO human_bindings')) {
      pgSql = `
        INSERT INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (signer_address) DO UPDATE SET
          nullifier_hash = EXCLUDED.nullifier_hash,
          bound_at = EXCLUDED.bound_at,
          expires_at = EXCLUDED.expires_at
      `;
    }
    return pgSql;
  }

  private asyncWriteToPostgres(sql: string, params: any[]): Promise<void> {
    if (!this.isPostgres || !this.pgPool) return;

    let pgSql = this.toPostgresSql(sql);
    let paramIdx = 1;
    pgSql = pgSql.replace(/\?/g, () => `$${paramIdx++}`);

    this.pgPool.query(pgSql, params).catch((err: any) => {
      this.logger.warn(`PostgreSQL background sync warning: ${err.message}`);
    });
  }
}
