# TICKET CLEAN-001: Zero-Fallback Violations & Code Hygiene

**Component:** `backend/`, `chapter2/`, `native_security/` · **Priority:** Medium · **Read first:** `docs/tickets/README.md`

Each group below is its own small commit. Items already handled by PAY-002/PAY-004 are skipped here, so check which tickets have landed first.

## A. Backend fallbacks (fail fast, or return an explicit error)
- **Addresses:** `backend/src/agents/agents.service.ts` (`ensureDefaultAgentForUser`) falls back to `SAFE_ADDRESS || '0x4f71…'`, `GUARD_ADDRESS || '0x9b60…'` and `CHAIN_ID … : 84532`. Require the env vars.
- **Database URL:** `backend/src/prisma/db.ts` and `backend/src/database/database.service.ts` use a default `DATABASE_URL` that includes a password. Require `DATABASE_URL`.
- **Chain id:** `backend/src/agents/agents.service.ts` has `dto.chainId || 84532`. Require it in the DTO or use `CHAIN_ID`.
- **Fake balance:** `backend/src/policies/mandates.controller.ts` `getActiveMandate` starts with a fake `totalTreasuryBalanceUsdc = 10.0` / `treasuryEthBalance = '0.001'` and silently keeps it when the RPC fails. Return `null` plus a `balanceError` field instead. `GET /mandates/active` is the Render health check, so keep it returning 200.
- **Ledger passphrase:** `backend/src/ledger/ledger-keyring.service.ts` falls back to `WALLET_PASS || 'chapter2_secure_ledger_ring_master'` with a fixed salt `'ledger_keyring_salt'`. Require `WALLET_PASS` outside tests, and store a random salt with each ciphertext (format `salt:iv:authTag:ciphertext`). Keep decrypting the old format if any exists.
- **Catalog URL:** `backend/src/vendor/vendor.service.ts` has `RENDER_EXTERNAL_URL || 'https://chapter2-backend.onrender.com'` and the organization fallback `'Acme Global Enterprises Inc.'`. Require the env var; organization is already a required DTO field.
- **Account projects:** `backend/src/vendor/vendor.service.ts` has `projects || ['default-project']`. Use `[]`.

## B. Mobile fallbacks
- **Fake identity:** `chapter2/lib/features/settings/view/settings_screen.dart` shows `user?.email ?? 'operator@chapter2.finance'` and `user?.id ?? 'did:privy:anonymous'`, which the rules explicitly forbid, plus the agent/Safe address fallback `'0x4f71…'`. Render an error or loading state instead.
- **Agent fallback:** `chapter2/lib/features/dashboard/cubit/dashboard_cubit.dart` (around lines 59 and 96) uses `?? '0x4f712dd7…'` as the agent. Emit a failure state when no agent is bound.
- **Risk score:** `chapter2/lib/features/guardian_alert/models/guardian_decision.dart` defaults `riskScore ?? 0`. A missing risk score must not read as zero risk; throw a `FormatException`.
- **Agent model:** `chapter2/lib/features/auth/models/agent_model.dart` defaults name, `chainId` (84532) and status. Require them.
- **Config IDs:** `chapter2/lib/core/config/app_config.dart` hardcodes `defaultValue`s for the Privy app/client IDs and backend URL. Remove them and require `--dart-define` / `.env`. Update `chapter2/.env.example` and the README run command.

## C. Schema drift
`backend/prisma/schema.prisma` doesn't match the raw SQL in `DatabaseService`:
- **Table names:** the SQL uses `"user"` and `agent`; Prisma maps `users` and `agents`.
- **Soft delete:** `deletedAt` is missing from `User`.
- **Agent status:** the comment says `ACTIVE, PAUSED, REVOKED` but the code writes `INACTIVE`.
- **Receipts table:** `x402_payment_receipts` (SEC-004) is missing.

Pick one source of truth. Recommended: align `schema.prisma` with the tables `initPostgresSchema` actually creates. Don't drop data.

## D. Hygiene
- **Banners:** remove decorative `// ----` / `// --- X ---` banner comments in `backend/src/vendor/vendor.service.ts`, `chapter2/lib/features/bills/view/company_bills_screen.dart` and `chapter2/lib/services/api/chapter2_api_service.dart` (rule 7).
- **Types:** replace `any` in `VendorController` return types with the real types.
- **Broadcasting spec:** `backend/src/blockchain/on-chain-executor.service.spec.ts` broadcasts real transactions. Split the tests that broadcast into `*.onchain.spec.ts`, excluded by default via jest `testPathIgnorePatterns`, and add an `npm run test:onchain` script.
- **Duplicate native code:** `native_security/` (standalone Swift/Kotlin packages) duplicates the code inside `packages/ledger_keyring` and `packages/agent_security`, which the app actually uses. 👤 Confirm with the user, then remove `native_security/` or turn it into the single source that the packages reference.

## Acceptance criteria
- **Fallback grep is clean:** `grep -rnE "\|\| '0x|\?\? '0x|did:privy:anonymous|operator@chapter2" backend/src chapter2/lib` returns nothing.
- **Gates:** the backend and mobile gates pass.
