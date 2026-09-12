import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class PrismaService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);
  public client: any = null;

  async onModuleInit() {
    try {
      // Dynamic import for ESM compatibility in CommonJS runtime
      // @ts-ignore
      const postgresMod = await import('@prisma/orm-postgres/runtime');
      const postgres = postgresMod.default || postgresMod;

      const candidates = [
        path.resolve(__dirname, '../prisma/contract.json'),
        path.resolve(__dirname, '../../src/prisma/contract.json'),
        path.resolve(process.cwd(), 'src/prisma/contract.json'),
        path.resolve(process.cwd(), 'backend/src/prisma/contract.json'),
        path.resolve(process.cwd(), 'dist/src/prisma/contract.json'),
        path.resolve(process.cwd(), 'backend/dist/src/prisma/contract.json'),
      ];

      let contractJson: any = null;
      for (const p of candidates) {
        if (fs.existsSync(p)) {
          contractJson = JSON.parse(fs.readFileSync(p, 'utf-8'));
          break;
        }
      }

      if (!contractJson) {
        throw new Error('contract.json not found in candidate paths');
      }

      this.client = postgres({
        contractJson,
        url:
          process.env.DATABASE_URL ||
          'postgresql://chapter2:chapter2_secret@localhost:5433/chapter2_db',
      });
      this.logger.log('Prisma ORM initialized with PostgreSQL');
    } catch (err: any) {
      this.logger.warn(`Prisma ORM initialization note: ${err.message}`);
    }
  }

  async onModuleDestroy() {
    // Teardown
  }
}
