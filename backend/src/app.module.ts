import { Module } from '@nestjs/common';
import { PoliciesModule } from './policies/policies.module';
import { ReservationsModule } from './reservations/reservations.module';
import { GuardianModule } from './guardian/guardian.module';
import { CryptoModule } from './crypto/crypto.module';
import { LedgerModule } from './ledger/ledger.module';

@Module({
  imports: [
    PoliciesModule,
    ReservationsModule,
    GuardianModule,
    CryptoModule,
    LedgerModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
