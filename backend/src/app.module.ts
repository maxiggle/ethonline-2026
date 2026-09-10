import { Module } from '@nestjs/common';
import { PoliciesModule } from './policies/policies.module';
import { ReservationsModule } from './reservations/reservations.module';
import { GuardianModule } from './guardian/guardian.module';

@Module({
  imports: [PoliciesModule, ReservationsModule, GuardianModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
