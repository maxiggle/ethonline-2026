import 'dotenv/config';
// @ts-ignore
import { definePrismaConfig } from '@prisma/cli-engine';
// @ts-ignore
import { defineConfig as ormConfig } from '@prisma/orm-postgres/config';

export default definePrismaConfig({
  orm: ormConfig({
    contract: './src/prisma/contract.prisma',
    db: {
      connection: process.env['DATABASE_URL'] || 'postgresql://chapter2:chapter2_secret@localhost:5433/chapter2_db',
    },
  }),
});
