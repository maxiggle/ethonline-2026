import { Module } from '@nestjs/common';
import { PoliciesModule } from './policies/policies.module';
import { ReservationsModule } from './reservations/reservations.module';
import { GuardianModule } from './guardian/guardian.module';
import { CryptoModule } from './crypto/crypto.module';
import { LedgerModule } from './ledger/ledger.module';
import { WorldModule } from './world/world.module';
import { GatewayModule } from './gateway/gateway.module';
import { ActionsModule } from './actions/actions.module';

@Module({
  imports: [
    PoliciesModule,
    ReservationsModule,
    GuardianModule,
    CryptoModule,
    LedgerModule,
    WorldModule,
    GatewayModule,
    ActionsModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
