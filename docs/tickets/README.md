# Chapter 2 Tickets

Each ticket is self-contained and meant to be handed to an implementation agent.
Read this file first, then the whole ticket.

---

## Submission track: ETHOnline 2026

Goal: a working, demoable **x402 v2 + Ledger** agent-payment flow.

- **Autonomous payments:** an AI agent pays for real x402 resources on **Base Sepolia USDC**.
  - Every payment is evaluated by the Chapter 2 Guardian first (ALLOW / ESCALATE / BLOCK).
  - Autonomous payments are signed by an agent wallet whose key is protected by the **Ledger Key Ring (`wallet-cli ring`)**. That CLI is a hard requirement of the Ledger prize.
- **Escalated payments** are **signed on the human's Ledger (Nano X / Flex) through a web approval console** (Ledger DMK over WebHID).
- **Settlement:** every payment is settled by the public x402 facilitator.

| Order | Ticket | Depends on | Parallel lane | Time box |
|---|---|---|---|---|
| 1 | [LEDGER-001: Key Ring-protected agent wallet](TICKET-LEDGER-001-KEY-RING-AGENT-WALLET.md) | none | Lane A (👤 human steps + small script) | 45 min |
| 1 | [X402-001: x402 v2 seller endpoints](TICKET-X402-001-X402-V2-SELLER.md) | none | Lane B | 1.5 h |
| 2 | [X402-002: Guardian-gated x402 payments API](TICKET-X402-002-GUARDIAN-GATED-PAYMENTS-API.md) | X402-001 (env/config only) | Lane B | 2.5 h |
| 3 | [LEDGER-002: Ledger web approval console](TICKET-LEDGER-002-WEB-APPROVAL-CONSOLE.md) | X402-002 API contract (can start from the contract) | Lane C | 2 h |
| 3 | [X402-003: Agent demo client](TICKET-X402-003-AGENT-DEMO-CLIENT.md) | LEDGER-001, X402-002 contract | Lane A | 1.5 h |
| 4 | [SUBMIT-001: Docs, DX feedback, demo](TICKET-SUBMIT-001-DOCS-AND-DEMO.md) | all | any | 45 min |

The API contract between X402-002, LEDGER-002 and X402-003 is fixed in X402-002. Lanes C and A can start as soon as that ticket is read; they don't need to wait for it to be implemented.

### Shared configuration (submission track)

| Variable | Where | Value / meaning |
|---|---|---|
| `X402_NETWORK` | backend | `eip155:84532` (Base Sepolia) |
| `X402_FACILITATOR_URL` | backend | `https://x402.org/facilitator` |
| `USDC_ADDRESS` | backend | Base Sepolia USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| `X402_PAY_TO_ADDRESS` | backend | Seller wallet that receives payments (a fresh address, not the agent or the Ledger) |
| `X402_PARTNER_PAY_TO_ADDRESS` | backend | A second seller address that is **not** approved (used to demo BLOCK) |
| `X402_APPROVED_PAY_TO` | backend | Comma-separated approved payees; must include `X402_PAY_TO_ADDRESS` and must not include the partner address |
| `X402_AUTONOMOUS_LIMIT` | backend | Per-payment autonomous cap in USDC atomic units, e.g. `1000000` ($1.00) |
| `X402_DAILY_LIMIT` | backend | Daily autonomous cap in atomic units, e.g. `5000000` ($5.00) |
| `LEDGER_APPROVER_ADDRESS` | backend, console | The human's Ledger Ethereum address (`44'/60'/0'/0/0`) that signs escalated payments |
| `PUBLIC_BASE_URL` | backend | Public URL of the backend, e.g. `http://localhost:3001` or the Render URL |
| `WALLET_PASS` | agent machine only | Ledger Key Ring password (from the macOS Keychain, never in files) |
| `AGENT_KEY_RING_FILE` / `AGENT_KEY_RING_KEY_NAME` | agent machine only | Encrypted agent key file and ring key name |
| `AGENT_KEY_SOURCE` | agent machine only | `ledger-key-ring` (demo) or `foundry-keystore` (testing); no default |
| `API_BASE_URL` | script | Backend URL |
| `VITE_API_BASE_URL`, `VITE_LEDGER_ORIGIN_TOKEN` | console | Backend URL; Ledger partner origin token if you have one (optional, never invented) |

Every backend variable above is **required**: fail at startup with a clear error if one is missing. No fallbacks.

### World ID Orb gate (WORLD-001 + MOBILE-004)

| Variable | Where | Value / meaning |
|---|---|---|
| `REQUIRE_WORLD_ID_FOR_ESCALATIONS` | backend | `true` or `false`, no default. When `true`, Ledger approvals need an active World ID Orb binding for `LEDGER_APPROVER_ADDRESS` |
| `WORLD_ID_APP_ID` / `WORLD_ID_RP_ID` | backend | `app_…` / `rp_…` from the World Developer Portal |
| `WORLD_ID_SIGNING_KEY` | backend | RP signing key from the Developer Portal (secret, set only in Render) |
| `WORLD_ID_ACTION` | backend | e.g. `chapter2-ledger-approver` |
| `WORLD_ID_ENVIRONMENT` | backend | `staging` (simulator) or `production` (World App) |

Set all five `WORLD_ID_*` variables, or none. A partial set, or `REQUIRE_WORLD_ID_FOR_ESCALATIONS=true` without them, is a startup error.

### Out of scope tonight
- **Deferred tickets:** the legacy Safe/Chapter2Guard execution path (`/actions` → relayer → MockSafe) and `/vendor/*` tx-hash endpoints stay as they are. PAY-001 … PAY-005, SEC-005, CLEAN-001 and DOCS-001 are deferred until after submission.
- **The x402 rail must never call `OnChainExecutorService` execution methods**, because the backend must never broadcast transactions. `verifyTokenTransfer` is read-only and fine to use.
- **Mobile Flutter app changes:** none are required. Actions created by the x402 rail still show up in the existing activity timeline because they are stored as `TreasuryAction`s.

---

## Status (2026-09-13)

| Ticket | Status |
|---|---|
| [LEDGER-001: Key Ring agent wallet](TICKET-LEDGER-001-KEY-RING-AGENT-WALLET.md) | ✅ Code done and verified; live Ledger run pending (device is with a remote tester) |
| [X402-001: x402 v2 seller](TICKET-X402-001-X402-V2-SELLER.md) | ✅ Live on Render |
| [X402-002: Guardian-gated payments API](TICKET-X402-002-GUARDIAN-GATED-PAYMENTS-API.md) | ✅ Live on Render |
| [LEDGER-002: web approval console](TICKET-LEDGER-002-WEB-APPROVAL-CONSOLE.md) | ✅ Code done; live device run pending |
| [X402-003: agent demo client](TICKET-X402-003-AGENT-DEMO-CLIENT.md) | ✅ Code done and verified |
| [X402-004: purchase requests + agent worker](TICKET-X402-004-AGENT-PURCHASE-REQUESTS.md) | ✅ Live on Render |
| [MOBILE-001: Ledger Bluetooth approvals](TICKET-MOBILE-001-LEDGER-BLE-X402-APPROVALS.md) | ✅ Code done and verified; live device run pending |
| [MOBILE-002: simplified UI and onboarding](TICKET-MOBILE-002-SIMPLIFY-UI-AND-ONBOARDING.md) | ✅ Done and verified |
| [MOBILE-003: Services tab](TICKET-MOBILE-003-SERVICES-TAB.md) | ✅ Done and verified |
| [SUBMIT-001: docs, DX feedback, demo](TICKET-SUBMIT-001-DOCS-AND-DEMO.md) | ✅ Docs, partner pages and DX feedback done; video pending |
| [SEC-004: legacy x402 tx verification](TICKET-SEC-004-X402-PAYMENT-VERIFICATION.md) | ✅ Done (legacy `/vendor/*` rail) |
| [PAY-001: replace the development wallet](TICKET-PAY-001-KEY-ROTATION-REDEPLOY.md) | ✅ Relayer key removed from the backend (executor is read-only). 👤 Move funds off the old development wallet and the retired MockSafe, and delete the keys from Render |
| [PAY-002](TICKET-PAY-002-TOKEN-AND-MANDATE-CONFIG.md) … [PAY-005](TICKET-PAY-005-MOBILE-SIGNING-AND-API.md), [SEC-005](TICKET-SEC-005-USER-SCOPING-AND-WEBSOCKET-AUTH.md), [CLEAN-001](TICKET-CLEAN-001-ZERO-FALLBACK-AND-HYGIENE.md), [DOCS-001](TICKET-DOCS-001-DOCUMENTATION-REFRESH.md) | Deferred / superseded by the x402 architecture |
| [WORLD-001: Orb-verified Ledger approver (backend)](TICKET-WORLD-001-ORB-VERIFIED-LEDGER-APPROVER.md) | 🚧 In progress. Replaces the Selfie Check plan with World ID Orb (staging + simulator) |
| [MOBILE-004: World ID Orb step in the app](TICKET-MOBILE-004-WORLD-ID-ORB-APPROVER.md) | 🚧 In progress, in parallel with WORLD-001 against its API contract |

**Designed, not built:**
- a signed agent-binding challenge.

Current architecture: [ARCHITECTURE.md](../ARCHITECTURE.md). Branch `feature/backend-security-hardening` is merged into `main`.

## Rules every ticket must follow

1. **Repo rules:** read `AGENTS.md` and, if present locally, `.agents/rules/*.md`. In short:
   - No hardcoded fallbacks, mock values, invented data or fake hashes in runtime code.
   - Stage explicit paths only (`git add <path>`).
   - Conventional commits with a scope (`backend`, `mobile`, `contracts`, `client`, `console`, `docs`, `repo`) and a 1–3 bullet body.
   - No decorative `// ----` banners.
   - Use the domain lexicon: `TreasuryAction`, `ALLOW/ESCALATE/BLOCK`, `humanSigner`, `autonomousAgent`.
2. **Commit trailers:** no `Co-Authored-By` trailer in commit messages.
3. **Git limits:** never `git push`, amend, or rewrite history unless the user explicitly asks.
4. **Private keys:** never print, log, commit or write private keys or `WALLET_PASS` to disk.
5. **Verification gates.** Run the relevant ones before every commit:
   - **Backend:** `cd backend && npx tsc --noEmit -p tsconfig.json && npx jest --runInBand --forceExit --testPathIgnorePatterns on-chain-executor.service.spec`. ESLint isn't installed.
   - **Mobile:** `cd chapter2 && flutter analyze && flutter test`.
   - **Contracts:** `cd contracts && forge test -vvv`.
   - **Scripts / console:** `npx tsc --noEmit` in the package, plus its own unit tests.
6. **Test gotchas:**
   - **Test-only paths:** jest sets `NODE_ENV=test`, which enables `test_token_<did>` auth, World ID `SANDBOX` and the `0xA11CE` Ledger key.
   - **Guard overrides:** unit specs for `PrivyAuthGuard`-protected controllers need `.overrideGuard(PrivyAuthGuard).useValue({ canActivate: () => true })`.
   - **Local Postgres:** `DatabaseService.initialize()` connects to the local Postgres (`localhost:5433`) when it is running, so use random ids and hashes in tests.
   - **Broadcasting spec:** `backend/src/blockchain/on-chain-executor.service.spec.ts` broadcasts real transactions. Keep it out of routine runs.
7. **SDK accuracy:** SDK code in these tickets is a sketch. Before writing code, pin exact package versions (`npm view <pkg> version`) and follow the installed package's README, types and official examples.
