import 'dotenv/config';
// @ts-ignore
import postgres from '@prisma/orm-postgres/runtime';
import type { Contract } from './contract.d';
const contractJson = require('./contract.json');

export const db = postgres<Contract>({
  contractJson,
  url: process.env['DATABASE_URL'] || 'postgresql://chapter2:chapter2_secret@localhost:5433/chapter2_db',
});
