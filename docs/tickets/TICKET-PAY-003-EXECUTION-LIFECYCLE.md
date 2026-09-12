# TICKET PAY-003: Treasury Action Execution Lifecycle

**Component:** `backend/` · **Priority:** High · **Depends on:** PAY-002 · **Read first:** `docs/tickets/README.md`

## Problem
1. **Escalated executions always revert.** `ActionsController` builds the EIP-712 approval with `mandateHash = computeMandateHash(mandate)` (keccak of `CHAPTER2_MANDATE_<chain>_<safe>_<guard>`). `OnChainExecutorService.executeEscalatedPayment` rebuilds it with `mandateHash = eip712Service.computeDomainSeparator(...)`. The Guard hashes the `mandateHash` it is given, so the recovered signer never matches and Chapter2Guard reverts with `InvalidSignature`.
2. **Execution failures are silently swallowed.** `executeAutonomousPayment(action).catch(() => {})` and `executeEscalatedPayment(...).catch(() => {})` in `backend/src/actions/actions.controller.ts` hide errors. The action stays `APPROVED` forever, the reservation stays committed (daily spend is consumed with no transfer), and no event is emitted.
3. **Execution is fire-and-forget.** Callers (VendorService, the mobile app, scripts) can't learn the `txHash`.

## Implementation
1. **One source for `mandateHash`:**
   - Add `computeMandateHash(mandate)` to `Eip712Service` (or a small helper in `crypto/`).
   - Use it in `ActionsController` (propose, clear-sign, approve) **and** in `OnChainExecutorService.executeEscalatedPayment`.
   - Add a unit test that the payload encoded for execution equals the one the human signed: decode `encodeEscalatedPayload` and compare it to `generateTypedData(...).message`.
2. **New status `EXECUTION_FAILED`** in `TreasuryActionStatus` (`backend/src/domain/treasury-action.entity.ts`). Check the mobile `TreasuryAction` model parses unknown statuses safely.
3. **Reservations follow the chain:** commit the reservation only after a mined receipt with `status === 1`.
   - Autonomous: `APPROVED` holds the reservation; `EXECUTED` commits it; `EXECUTION_FAILED` releases it.
   - Escalated: the same flow after approval.
   - Check `BalanceReservationService` supports "hold after approval, commit on execution" (TTL is 300 s by default, so extend the TTL for approved actions or hold explicitly).
4. **Replace `.catch(() => {})`:**
   - Add a method, e.g. `dispatchExecution(action, signature?)`, that awaits the executor.
   - On failure: mark the action `EXECUTION_FAILED` and store the error message (add a nullable `failure_reason` column to `treasury_actions` in `DatabaseService`, following the `x402_payment_receipts` pattern), release the reservation, and emit a new `action:execution_failed` event from `EventsGateway`.
   - Keep the HTTP response non-blocking: return immediately with status `APPROVED`, and let the dispatch run in the background with **handled** errors.
5. **`OnChainExecutorService`:** keep `runWithMutex`. Its current `catch` rethrows `BadRequestException`; convert that to a domain error so the dispatcher decides the status.
6. **Tests:** mock the executor. Cover:
   - A successful execution leads to `EXECUTED` with the reservation committed.
   - A rejected execution leads to `EXECUTION_FAILED`, the reservation released, and the event emitted.
   - The escalated `mandateHash` matches between approval and execution.

## Acceptance criteria
- **Signature matches:** an escalated action approved with a valid `humanSigner` signature produces a Safe tx whose Guard signature check passes. Prove this in a local unit test with the Foundry test vector.
- **Failures are visible:** no execution error is swallowed, a failed execution never consumes the daily budget, and it is visible via status + event.
- **Gate:** the backend gate passes.
