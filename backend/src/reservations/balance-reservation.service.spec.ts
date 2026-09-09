import { BalanceReservationService } from './balance-reservation.service';
import { PolicyEngineService } from '../policies/policy-engine.service';

describe('BalanceReservationService', () => {
  let reservationService: BalanceReservationService;
  let policyEngine: PolicyEngineService;

  beforeEach(() => {
    policyEngine = new PolicyEngineService();
    reservationService = new BalanceReservationService(policyEngine);
  });

  it('should successfully acquire reservation within available budget', () => {
    const res = reservationService.acquireReservation('act-1', '100000000');
    expect(res.success).toBe(true);
    expect(res.reservation).toBeDefined();
    expect(res.reservation?.amount).toBe(BigInt('100000000'));
    expect(reservationService.getTotalReservedAmount()).toBe(BigInt('100000000'));
  });

  it('should prevent double-spending when concurrent reservations exceed budget', () => {
    const fixedTime = 1700000000;
    reservationService.acquireReservation('act-1', '400000000', 300, fixedTime);

    const res2 = reservationService.acquireReservation('act-2', '150000000', 300, fixedTime);
    expect(res2.success).toBe(false);
    expect(res2.reason).toContain('Insufficient remaining daily budget');
  });

  it('should commit reservation to policy engine and clear active reservation', () => {
    const fixedTime = 1700000000;
    reservationService.acquireReservation('act-1', '100000000', 300, fixedTime);

    const committed = reservationService.commitReservation('act-1', fixedTime);
    expect(committed).toBe(true);
    expect(reservationService.getTotalReservedAmount(fixedTime)).toBe(BigInt(0));
    expect(policyEngine.getDailySpent(fixedTime)).toBe(BigInt('100000000'));
  });

  it('should release reservation and restore capacity', () => {
    const fixedTime = 1700000000;
    reservationService.acquireReservation('act-1', '400000000', 300, fixedTime);

    const released = reservationService.releaseReservation('act-1');
    expect(released).toBe(true);
    expect(reservationService.getTotalReservedAmount(fixedTime)).toBe(BigInt(0));

    const res2 = reservationService.acquireReservation('act-2', '200000000', 300, fixedTime);
    expect(res2.success).toBe(true);
  });

  it('should prune expired reservations', () => {
    const initialTime = 1700000000;
    reservationService.acquireReservation('act-1', '100000000', 60, initialTime);

    const futureTime = initialTime + 61;
    expect(reservationService.getTotalReservedAmount(futureTime)).toBe(BigInt(0));
    expect(reservationService.getReservation('act-1')).toBeUndefined();
  });
});
