import { Module } from '@nestjs/common';
import { CryptoModule } from '../crypto/crypto.module';
import { LedgerKeyRingService } from './ledger-keyring.service';
import { LedgerController } from './ledger.controller';

@Module({
  imports: [CryptoModule],
  controllers: [LedgerController],
  providers: [LedgerKeyRingService],
  exports: [LedgerKeyRingService],
})
export class LedgerModule {}
