# TICKET PAY-004: End-to-End x402 Settlement Flow

**Component:** `backend/`, `scripts/` · **Priority:** High · **Depends on:** SEC-004, PAY-003 · **Read first:** `docs/tickets/README.md`

## Problem
After SEC-004 and PAY-003, x402 payments are verified and executions report their outcome. The flows still don't complete, though:
1. **Invocations stop at pending.** `VendorService.invokeService` and `VendorController.payBill` propose a payment and return before it is mined (`PENDING_SETTLEMENT`). Nothing later delivers the service response or settles the bill.
2. **The service data is fabricated.** The weather "oracle" (`buildWeatherTelemetry`) and the compute grant return hardcoded data (San Francisco 18.5 °C, "1x NVIDIA H100", `allocatedVramGb: 80`), which violates `.agents/rules/zero_fallback_policy.md`.
3. **The demo client can't finish.** `scripts/agent-x402-client.ts` reads `txHash` straight from the pay response and never waits for settlement.

## Implementation
1. **Settlement on execution:** when an action reaches `EXECUTED` (PAY-003 dispatcher), find the bill or invocation it paid for and call `settleBillWithPayment` / `redeemPayment`.
   - Store the link when proposing. Recommended: a new `x402_payment_intents` table (`action_id`, `resource_id`, `bill_id` nullable, `status`), persisted like `x402_payment_receipts`.
   - Emit `vendor:bill_settled` / `vendor:invocation_ready` events.
2. **`GET /vendor/invocations/:actionId`:** a guarded, ownership-checked route that returns the invocation status and, once settled, the resource response.
3. **Real resource data (choose one and document it; 👤 confirm with user):**
   - (a) Proxy a real weather API. Add an env API key and fail fast if it's missing.
   - (b) Rename these endpoints to test resources whose response is explicitly the verified payment receipt (tx hash, amount, block number) with no invented telemetry.

   Remove the hardcoded compute "H100" grant either way.
4. **`scripts/agent-x402-client.ts`:** after paying or calling, poll `GET /actions/:id` (authenticated) until `EXECUTED` or `EXECUTION_FAILED`, with a timeout. Then fetch the resource with `X-Payment-TxHash`. Print a Blockscout link (`https://base-sepolia.blockscout.com/tx/<hash>`) instead of `sepolia.base.org/tx`.
5. **Tests:** mock the executor and events. Cover `EXECUTED` settling the right bill or invocation, `EXECUTION_FAILED` leaving it unpaid, and invocation status transitions.

## Acceptance criteria
- **Full demo run:** against a deployment configured per PAY-001/PAY-002, `API_BASE_URL=… AUTH_TOKEN=… npx ts-node scripts/agent-x402-client.ts` completes this loop:
  1. 402 challenge
  2. propose (ALLOW)
  3. mined USDC transfer
  4. verified redemption
  5. real (or explicitly receipt-only) resource response
- **No fabricated data:** no invented service data remains in runtime code.
- **Gate:** the backend gate passes.
