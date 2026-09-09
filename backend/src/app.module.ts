import { Module } from '@nestjs/common';
import { PoliciesModule } from './policies/policies.module';
import { ReservationsModule } from './reservations/reservations.module';

@Module({
  imports: [PoliciesModule, ReservationsModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
