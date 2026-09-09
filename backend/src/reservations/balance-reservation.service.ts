import { Injectable } from '@nestjs/common';
import { PolicyEngineService } from '../policies/policy-engine.service';

export interface BalanceReservation {
  id: string;
  actionId: string;
  amount: bigint;
  expiresAt: number;
}

@Injectable()
export class BalanceReservationService {
  private activeReservations = new Map<string, BalanceReservation>();
  private readonly defaultTtlSeconds = 300;

  constructor(private readonly policyEngine: PolicyEngineService) {}

  public acquireReservation(
    actionId: string,
    amountStr: string,
    ttlSeconds: number = this.defaultTtlSeconds,
    currentTimestamp: number = Math.floor(Date.now() / 1000),
  ): { success: boolean; reservation?: BalanceReservation; reason?: string } {
    this.pruneExpired(currentTimestamp);

    const amount = BigInt(amountStr);
    const mandate = this.policyEngine.getMandate();
    const currentDailySpent = this.policyEngine.getDailySpent(currentTimestamp);
    const currentReserved = this.getTotalReservedAmount(currentTimestamp);

    if (currentDailySpent + currentReserved + amount > mandate.dailyAutonomousLimit) {
      return {
        success: false,
        reason: `Insufficient remaining daily budget after accounting for active reservations. Current spent: ${currentDailySpent.toString()}, reserved: ${currentReserved.toString()}, requested: ${amountStr}.`,
      };
    }

    const reservation: BalanceReservation = {
      id: `res-${actionId}`,
      actionId,
      amount,
      expiresAt: currentTimestamp + ttlSeconds,
    };

    this.activeReservations.set(actionId, reservation);
    return { success: true, reservation };
  }

  public commitReservation(
    actionId: string,
    currentTimestamp: number = Math.floor(Date.now() / 1000),
  ): boolean {
    const reservation = this.activeReservations.get(actionId);
    if (!reservation) {
      return false;
    }

    this.policyEngine.recordAutonomousSpend(reservation.amount.toString(), currentTimestamp);
    this.activeReservations.delete(actionId);
    return true;
  }

  public releaseReservation(actionId: string): boolean {
    return this.activeReservations.delete(actionId);
  }

  public getReservation(actionId: string): BalanceReservation | undefined {
    return this.activeReservations.get(actionId);
  }

  public getTotalReservedAmount(currentTimestamp: number = Math.floor(Date.now() / 1000)): bigint {
    this.pruneExpired(currentTimestamp);
    let total = BigInt(0);
    for (const reservation of this.activeReservations.values()) {
      total += reservation.amount;
    }
    return total;
  }

  public pruneExpired(currentTimestamp: number = Math.floor(Date.now() / 1000)): number {
    let pruned = 0;
    for (const [actionId, res] of this.activeReservations.entries()) {
      if (res.expiresAt <= currentTimestamp) {
        this.activeReservations.delete(actionId);
        pruned++;
      }
    }
    return pruned;
  }
}
