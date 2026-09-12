# TICKET PAY-005: Mobile Real EIP-712 Signing & API Contract Updates

**Component:** `chapter2/` (Flutter) · **Priority:** High · **Depends on:** PAY-003 · **Read first:** `docs/tickets/README.md`

## Problem
1. **Fake approval signature.** Escalation approval sends the literal string `'0x_privy_biometric_signature_placeholder'` (`chapter2/lib/features/dashboard/view/dashboard_screen.dart` around line 1234). Check `chapter2/lib/features/bills/view/company_bills_screen.dart` around line 2153 for the same thing. That breaks the zero-fallback rule, and the backend now rejects it.
2. **The biometric step is skipped.** `ApprovalCubit.approveWithPrivyBiometrics` and `confirmBiometricChallenge` emit `biometricsVerified` without doing any biometric check.
3. **Wrong signer.** The approval signer is the user's Privy wallet, which is also the autonomous agent. The backend now requires the signer to be the Chapter2Guard `humanSigner` (a separate key per PAY-001, ideally a Ledger through `packages/ledger_keyring`).
4. **API calls the app has to update.** Backend changes on `feature/backend-security-hardening` break these:
   - `Chapter2ApiService.verifyWorldIdSelfie` posts to `/world/verify-selfie`, which doesn't exist. The route is `POST /world/selfie/verify`, and `/world/selfie/bind` requires `signerAddress` == the logged-in wallet.
   - `payCompanyBill` and `invokeBazaarService` send `agentAddress` as optional; the backend now **requires** it (an ACTIVE agent owned by the user).
   - The backend returns 403 for non-owned agents and 401 without a token.
   - New invocation statuses: `BLOCKED`, `PENDING_SETTLEMENT` (and `EXECUTION_FAILED` for actions after PAY-003).

## Implementation
1. **Signing:**
   - Fetch the typed data from the escalation (`action:escalated` payload `typedData`, or `GET /actions/:id/clear-sign`).
   - Sign it with EIP-712 through the configured human signer. Use `ledger_keyring` (a Ledger over BLE) when available. If the product decision is to let a Privy wallet act as `humanSigner`, use Privy's `eth_signTypedData_v4`, and that wallet must be the one set as `humanSigner` on-chain.
   - Gate the signing on a real `local_auth` / Secure Enclave biometric prompt, and only emit `biometricsVerified` after it succeeds.
   - Surface backend 400/403 errors to the user.
2. **API service (`chapter2/lib/services/api/chapter2_api_service.dart`):**
   - Fix the World ID route.
   - Make `agentAddress` required in `payCompanyBill` / `invokeBazaarService`, sourcing it from the active bound agent (`GET /agents`).
   - Map 401 to logout and 403 to a clear "agent not owned" error.
3. **Models:** accept the new statuses (`BLOCKED`, `PENDING_SETTLEMENT`, `EXECUTION_FAILED`) without crashing, and show them in bills and activity.
4. **Tests:**
   - Update `test/tri_verdict_pipeline_test.dart` and `test/approval_cubit_test.dart` so approval requires a real signature from the signer service (mocked in tests).
   - Add a test that the cubit refuses to submit when the biometric prompt fails.
   - Replace invalid fixture addresses such as `'0x999'` and `'0xAgent001'` with valid 20-byte hex addresses.

## Acceptance criteria
- **No placeholders:** no placeholder signature or skipped biometric step remains.
- **Working approval:** an escalation approved on the device passes backend `approveAction` (signer == Guard `humanSigner`) and executes on-chain.
- **Bills and Bazaar:** pay and call work against the secured backend.
- **Gate:** `flutter analyze && flutter test` passes.
