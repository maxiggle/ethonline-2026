# TICKET PAY-002: Real ERC-20 Treasury Token & On-Chain Mandate Configuration

**Component:** `backend/` · **Priority:** High · **Depends on:** PAY-001 · **Read first:** `docs/tickets/README.md`

## Problem
1. **The "token" is the Safe.** The backend treats the MockSafe address as the treasury token (`VendorService.tokenAddress = SAFE_ADDRESS`, and `PolicyEngineService.approvedTokens` includes `SAFE_ADDRESS` and the zero address). MockSafe is not an ERC-20.
2. **"Executed" payments move nothing.** `OnChainExecutorService.executeAutonomousPayment` / `executeEscalatedPayment` treat `token == safeAddress` as a native transfer: `value = action.value` (`'0'`), `data = '0x'`. So "EXECUTED" payments send zero-value no-op calls.
3. **Vendor recipient fallbacks.** `VendorService.vendorAddress` falls back to `SAFE_ADDRESS` and then `0x000…000`.
4. **Backend and chain can disagree.** `PolicyEngineService` hardcodes caps (100/500 USDC), approved recipients (`0x…41c4e`, `0x…cf`) and `humanSigner` (falls back to the Safe address). A value persisted in the DB can override the chain.

## Implementation
1. **Env, fail fast:** require `USDC_ADDRESS` (Base Sepolia USDC is `0x036CbD53842c5426634e7929541eC2318f3dCF7e`) and `VENDOR_RECIPIENT_ADDRESS`. Throw at startup if either is missing. Remove the fallbacks in `on-chain-executor.service.ts` (`getTreasuryBalance`) and `vendor.service.ts`.
2. **`VendorService`:** `tokenAddress = USDC_ADDRESS`, and the recipient comes from `VENDOR_RECIPIENT_ADDRESS`. Every entry in `getBazaarCatalog` and every bill's `paymentRequirements` uses them.
3. **`OnChainExecutorService`:**
   - Always encode `transfer(recipient, amount)` against `action.token`.
   - Reject (throw) any action whose token isn't a contract with `decimals()`.
   - Remove the "token equals safe means native" branch.
4. **`PolicyEngineService`:**
   - Build the mandate from chain state on startup: `maxAutonomousAmount()`, `dailyAutonomousLimit()`, `humanSigner()`, `safeAddress()`, and `isApprovedToken` / `isApprovedRecipient` for the configured token and the known vendor recipients (from `VENDOR_RECIPIENT_ADDRESS` plus an optional comma-separated `APPROVED_RECIPIENTS`).
   - Remove the hardcoded defaults and the `LEDGER_SIGNER_ADDRESS || <safe>` fallback.
   - The constructor is synchronous, so add an `onModuleInit` that awaits the chain read, and block proposals until it has loaded.
   - `updateMandate` (from `MandatesController`) must not loosen limits beyond on-chain values. Either remove those REST mutations or only allow tightening, and document the choice.
5. **Tests:** update specs that use `0x4f71…1df6` as a token so they use a token env/fixture. Mock chain reads in unit specs; never broadcast.

## Acceptance criteria
- **Consistent config:** the token, recipients, caps and `humanSigner` used by the backend always equal the deployed Guard's configuration.
- **Real transfers:** an autonomous ALLOW of 40 USDC produces an ERC-20 `Transfer` of 40 USDC from the Safe to the vendor recipient.
- **Fail fast:** no zero-address or Safe-as-token fallbacks remain, and a missing env var stops startup.
- **Gate:** the backend gate passes.
