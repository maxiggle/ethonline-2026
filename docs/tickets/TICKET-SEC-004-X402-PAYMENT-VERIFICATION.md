# TICKET SEC-004: x402 On-Chain Payment Verification & Replay Protection

**Component:** `backend/` · **Priority:** Critical · **Read first:** `docs/tickets/README.md`

## Problem
Paid x402 resources can currently be unlocked without paying.

1. **Any successful tx unlocks access.** `VendorService.verifyAndGrantAccess` (`backend/src/vendor/vendor.service.ts`) accepts any tx hash whose receipt has `status === 1` (`OnChainExecutorService.verifyTransaction`). It never checks the recipient, token or amount.
2. **Unverified actions are trusted.** If the hash matches a local `TreasuryAction`, it is accepted even when the status is `APPROVED` (nothing mined). `EXECUTED` doesn't prove a transfer happened either.
3. **Unlimited replay.** The same tx hash can be reused forever, for any resource.
4. **Bills settle before verification.** `VendorController.getBill` calls `markBillSettled` *before* verifying, so a failed check still leaves the bill settled.
5. **The wrong bill gets settled.** After any compute unlock, `verifyAndGrantAccess` settles the *first* `UNPAID_402` bill, whichever bill was paid.
6. **Weather needs no payment.** `GET /vendor/weather` returns data for any string in `X-Payment-TxHash`, with no verification.
7. **Unknown resources get silently paid.** `invokeService` falls back to `catalog[0]` for unknown resources, so the agent pays for a service it didn't ask for.
8. **Failed payments report SUCCESS.** `invokeService` returns `SUCCESS` for a `BLOCK` decision, and when no `txHash` exists yet (execution is async).

## Head start (uncommitted)
`backend/src/database/database.service.ts` and `database.interface.ts` already add:
- **Table:** `x402_payment_receipts (tx_hash PK, resource, amount, redeemed_at)`, with Postgres DDL, load and file persistence.
- **Reads:** `querySync` supports `SELECT * FROM x402_payment_receipts WHERE tx_hash = ?`. Keys are lowercased.
- **Writes:** `runSync('INSERT INTO x402_payment_receipts (tx_hash, resource, amount, redeemed_at) VALUES (?, ?, ?, ?) ON CONFLICT (tx_hash) DO NOTHING', …)` returns `{ changes: 0 }` if the hash is already present.

Review these changes, compile them, add a spec, then commit.

## Implementation

### Commit 1: `feat(backend): persist redeemed x402 payment receipts`
Commit the database changes. In `database.service.spec.ts`, add a test that inserts the same **randomly generated** tx hash twice: the first insert gives `changes: 1`, the second `changes: 0`, and the stored `resource` stays the first one.

### Commit 2: `feat(backend): verify ERC-20 transfers in x402 payment receipts`
Add this to `OnChainExecutorService`:
```ts
async verifyTokenTransfer(
  txHash: string,
  expectedTransfer: { token: string; recipient: string; minimumAmount: bigint },
): Promise<{ verified: true; transferredAmount: bigint } | { verified: false; error: string; transferredAmount?: bigint }>
```
- **Receipt:** fetch it. Return `verified: false` if it's missing or `status !== 1`.
- **Logs:** decode `event Transfer(address indexed from, address indexed to, uint256 value)`. Only count logs where `log.address == token` **and** `to == recipient`, and sum their `value`.
- **Amount:** it is verified only when the total is `>= minimumAmount`.
- **Tests:** add a new spec, `on-chain-executor.payment-verification.spec.ts`, and do not touch the broadcasting spec.
  - Construct the service with `new OnChainExecutorService({} as any, {} as any, {} as any, {} as any)`.
  - `jest.spyOn(service.provider, 'getTransactionReceipt')` and build logs with `Interface.encodeEventLog`.
  - Cover: a valid payment, the wrong recipient, the wrong token, an underpayment, a reverted receipt, and a missing receipt.

### Commit 3: `fix(backend): verify x402 payments on-chain per resource and block replays`
Changes in `vendor.service.ts`:
- **Constructor:** inject `DatabaseService`. Drop the `ActionStoreService` dependency; it's only used by the removed trust path.
- **New `redeemPayment(txHash, requirements: PaymentRequirements, resourceId: string): Promise<string>`:**
  1. Reject malformed hashes (`/^0x[0-9a-fA-F]{64}$/`) and requirements whose `chainId !== this.chainId`.
  2. Reject a hash that already exists in `x402_payment_receipts` ("already redeemed for <resource>").
  3. Call `onChainExecutor.verifyTokenTransfer({ token, recipient: requirements.address, minimumAmount: BigInt(requirements.amount) })`, and throw `BadRequestException` on failure.
  4. Insert the receipt. If `changes === 0`, reject it as a concurrent replay.
  5. Return the lowercased hash.
- **`verifyAndGrantAccess`:** call `redeemPayment(txHash, getPaymentRequirements(), 'vendor:compute')`. Remove the "settle first unpaid bill" code.
- **New `settleBillWithPayment(billId, txHash)`:**
  - If the bill is already settled with the same hash, return it.
  - If it's settled with a different hash, reject.
  - Otherwise call `redeemPayment(txHash, bill.paymentRequirements, 'bill:' + id)` and then `markBillSettled`. Make `markBillSettled` private.
- **Weather:** add `getWeatherPaymentRequirements()` (1 USDC, identifier `weather_oracle_inv_004`) and `getPaidWeatherTelemetry(city, txHash)`, which redeems before returning data. Remove the `'0x_settlement_unverified'` fallback.
- **`invokeService(resourceUrl, method, params, agentAddress)`:**
  - **Matching:** match the resource by URL path exactly, and throw `NotFoundException` when nothing matches. Validate the params (e.g. weather needs `city`) **before** proposing a payment.
  - **Result:** a status union `'SUCCESS' | 'ESCALATED' | 'BLOCKED' | 'PENDING_SETTLEMENT'`.
    - `BLOCK` gives `BLOCKED` and `ESCALATE` gives `ESCALATED`. Both use `decision.reasons` as the reason, which fixes the wrong "$500" text.
    - No `txHash` yet gives `PENDING_SETTLEMENT`.
    - Otherwise, redeem for that resource and return the data.

Changes in `vendor.controller.ts`:
- **`getBill`** with `X-Payment-TxHash`: `return vendorService.settleBillWithPayment(id, txHash)`.
- **`payBill`:** only when the proposal returned a `txHash`, call `settleBillWithPayment` inside try/catch. On failure, return the unsettled bill plus `settlementError`.
- **`getWeather`:** require `city` (400 if missing), return a 402 challenge from `getWeatherPaymentRequirements()`, then `getPaidWeatherTelemetry`.

`vendor.controller.spec.ts`:
- **Mocks:** replace the real `OnChainExecutorService` with `{ verifyTokenTransfer: jest.fn() }` and provide `DatabaseService`.
- **Keep:** the existing route-protection and ownership tests.
- **Add tests for:**
  - Compute unlocks only after verification, and `verifyTokenTransfer` is called with the compute requirements.
  - A replayed hash is rejected, and verification is called only once.
  - A malformed hash is rejected without calling verification.
  - An unverified payment is rejected.
  - Paying bill B settles only B, not an unpaid bill A.
  - A failed bill verification leaves the bill `UNPAID_402`.
  - A hash redeemed for compute can't unlock weather.
  - `invokeService`: `SUCCESS`, `PENDING_SETTLEMENT` (no txHash, no verification call), `BLOCKED`, and an unknown resource (404, no proposal).

## Acceptance criteria
- **Recipient, token and amount:** no x402 resource or bill unlocks unless an on-chain ERC-20 `Transfer` of at least the required amount of the required token went to the required recipient.
- **Replay:** each tx hash can be redeemed once across all resources, including after a restart (Postgres-backed).
- **Honest statuses:** no `SUCCESS` without verified payment data.
- **Gate:** the backend gate passes.

## Known limitation (document, don't fix)
Replay protection is atomic within a single backend instance. With several instances, the Postgres `ON CONFLICT` write is asynchronous. Note this in `docs/features/backend-onchain-persistence-x402.md`.
