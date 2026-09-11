import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';

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
      const contractJson = require('../prisma/contract.json');

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
