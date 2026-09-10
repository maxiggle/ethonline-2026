import { Module } from '@nestjs/common';
import { ActionsController } from './actions.controller';
import { ActionStoreService } from './action-store.service';
import { PoliciesModule } from '../policies/policies.module';
import { ReservationsModule } from '../reservations/reservations.module';
import { GuardianModule } from '../guardian/guardian.module';
import { CryptoModule } from '../crypto/crypto.module';
import { LedgerModule } from '../ledger/ledger.module';
import { WorldModule } from '../world/world.module';
import { GatewayModule } from '../gateway/gateway.module';

@Module({
  imports: [
    PoliciesModule,
    ReservationsModule,
    GuardianModule,
    CryptoModule,
    LedgerModule,
    WorldModule,
    GatewayModule,
  ],
  controllers: [ActionsController],
  providers: [ActionStoreService],
  exports: [ActionStoreService],
})
export class ActionsModule {}
