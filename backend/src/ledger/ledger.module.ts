import { Module } from '@nestjs/common';
import { CryptoModule } from '../crypto/crypto.module';
import { LedgerKeyRingService } from './ledger-keyring.service';

@Module({
  imports: [CryptoModule],
  providers: [LedgerKeyRingService],
  exports: [LedgerKeyRingService],
})
export class LedgerModule {}
