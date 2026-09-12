import { Module } from '@nestjs/common';
import { BalanceReservationService } from './balance-reservation.service';
import { PoliciesModule } from '../policies/policies.module';

@Module({
  imports: [PoliciesModule],
  providers: [BalanceReservationService],
  exports: [BalanceReservationService],
})
export class ReservationsModule {}
