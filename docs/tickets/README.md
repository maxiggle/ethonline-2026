# Chapter 2 Tickets: Security Hardening & Working Payments

Each ticket in this folder is self-contained and meant to be handed to an implementation agent.
Read this file first, and the whole ticket before starting it.

## Recommended order

| # | Ticket | Depends on | Owner |
|---|--------|------------|-------|
| 1 | [SEC-004: x402 on-chain payment verification & replay protection](TICKET-SEC-004-X402-PAYMENT-VERIFICATION.md) | none | agent |
| 2 | [PAY-001: Rotate leaked keys & redeploy Guard/Safe](TICKET-PAY-001-KEY-ROTATION-REDEPLOY.md) | none | **human + agent** |
| 3 | [PAY-002: Real ERC-20 treasury token & on-chain mandate config](TICKET-PAY-002-TOKEN-AND-MANDATE-CONFIG.md) | PAY-001 | agent |
| 4 | [PAY-003: Execution lifecycle (escalation signature bug, swallowed failures)](TICKET-PAY-003-EXECUTION-LIFECYCLE.md) | PAY-002 | agent |
| 5 | [PAY-004: End-to-end x402 settlement flow](TICKET-PAY-004-X402-SETTLEMENT-FLOW.md) | SEC-004, PAY-003 | agent |
| 6 | [PAY-005: Mobile signing & API contract updates](TICKET-PAY-005-MOBILE-SIGNING-AND-API.md) | PAY-003 | agent |
| 7 | [SEC-005: Per-user data scoping & WebSocket auth](TICKET-SEC-005-USER-SCOPING-AND-WEBSOCKET-AUTH.md) | none | agent |
| 8 | [CLEAN-001: Zero-fallback violations & code hygiene](TICKET-CLEAN-001-ZERO-FALLBACK-AND-HYGIENE.md) | PAY-002 (partly) | agent |
| 9 | [DOCS-001: Documentation refresh](TICKET-DOCS-001-DOCUMENTATION-REFRESH.md) | after the rest | agent |

## Current state (as of 2026-09-12)

Work branch: `feature/backend-security-hardening` (cut from `development`, **not pushed**).

Already done and committed on that branch:
- **Removed leaked key:** the hardcoded relayer private key is gone from the specs. It is still in git history (see PAY-001).
- **`PrivyAuthService`:**
  - `test_token_` identities work only when `NODE_ENV=test`.
  - Unsigned JWT decoding is removed.
  - The wallet comes from Privy only.
- **Global auth:** `AuthModule` is global, and `AuthenticatedRequest` (`backend/src/auth/interfaces/authenticated-request.interface.ts`) exists.
- **Protected routes:** `PrivyAuthGuard` plus `AgentsService.assertAgentOwnership` now cover `/actions`, `/ledger`, `/world/selfie`, mandate mutations, and vendor account/billing/invoke routes plus `/discovery/call`.
- **Still public:** `GET /mandates/active` (Render health check), x402 resource challenges (`GET /vendor/bills/:id`, `/vendor/compute`, `/vendor/weather`), and `/discovery/resources|search`.
- **World ID:** `SANDBOX` verification only runs under jest; otherwise `WORLD_ID_MODE=CLOUD_API` is required.
- **Ledger:**
  - The mock key `0xA11CE` is only loaded under jest.
  - `POST /ledger/sign` is removed.
  - `MOCK_HARDWARE` is refused outside tests.
- **Approvals:** the signer must equal `humanSigner()` read from the deployed Chapter2Guard (`OnChainExecutorService.getGuardHumanSigner`). World ID bindings are limited to the caller's own wallet.
- **Scripts:** `scripts/agent-x402-client.ts` requires `AUTH_TOKEN`.

**Uncommitted work in progress:** `backend/src/database/database.service.ts` and `database.interface.ts` add an `x402_payment_receipts` table. It belongs to SEC-004 and has not been compiled or tested yet.

## Deployed on-chain state (Base Sepolia, chain 84532), verified with `cast call`

- **Chapter2Guard:** `0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3`
  - `owner` = `humanSigner` = `0x988B225185b516DEF12A7Ec841abae9072ef4EE8`. This is the relayer, and **its private key was committed to the public repo**.
  - `autonomousAgent` = `0x45E6Cb4015a63b45048fD2B37Cc75fdb9D59f91c`.
  - `isApprovedToken` is `false` for both MockSafe and Base Sepolia USDC.
  - `checkTransaction` returns immediately when `msgSender == owner`. The relayer sends every Safe tx, so **no Guard rule is enforced today**.
- **MockSafe:** `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6`. It is not an ERC-20, yet the backend uses it as the "USDC token".

## Rules every ticket must follow

1. **Repo rules:** read `AGENTS.md`, `.agents/rules/zero_fallback_policy.md` and `.agents/rules/execution_discipline.md`. In short:
   - No hardcoded fallbacks, mock values or fake hashes in runtime code.
   - Small atomic commits (about 2 files / 150 lines where practical).
   - `git add <explicit paths>` only.
   - Conventional commits with a scope (`backend`, `mobile`, `contracts`, `client`, `docs`, `repo`) and a 1–3 bullet body.
   - No decorative `// ----` banner comments.
   - Use the domain lexicon: `TreasuryAction`, `TreasuryMandate`, `ALLOW/ESCALATE/BLOCK`, `humanSigner`, `autonomousAgent`.
2. **Commit trailers:** no `Co-Authored-By` trailer in commit messages.
3. **Git limits:** never `git push`, never amend, and never rewrite history unless the user explicitly asks.
4. **Verification gates.** Run these before every commit:
   - **Backend:** `cd backend && npx tsc --noEmit -p tsconfig.json && npx jest --runInBand --forceExit --testPathIgnorePatterns on-chain-executor`. ESLint isn't installed, so `npm run lint` can't run, and `npm run typecheck` doesn't exist.
   - **Mobile:** `cd chapter2 && flutter analyze && flutter test`.
   - **Contracts:** `cd contracts && forge test -vvv`.
5. **Test gotchas:**
   - **Test-only paths:** jest sets `NODE_ENV=test`, which enables them: `test_token_<did>` auth, World ID `SANDBOX`, and the `0xA11CE` Ledger key.
   - **Guard overrides:** unit specs for guarded controllers must use `.overrideGuard(PrivyAuthGuard).useValue({ canActivate: () => true })`.
   - **Internal vs route methods:** `ActionsController` has internal methods (`proposeAction`, `approveAction`, `rejectAction`) used by `VendorService` and specs, plus route handlers (`proposeActionForUser`, `approveActionForUser`, `rejectActionForUser`) that add ownership checks.
   - **Env and databases:** jest loads `backend/.env` through dotenv. `DatabaseService.initialize(':memory:')` still connects to the local Postgres (`localhost:5433`) when it is running, so test rows can land there. Use random ids and tx hashes in tests.
   - **Broadcasting spec:** `backend/src/blockchain/on-chain-executor.service.spec.ts` **broadcasts real Base Sepolia transactions** with the relayer key. Keep it out of routine runs. For new executor tests, use a separate spec that mocks `provider.getTransactionReceipt`.
