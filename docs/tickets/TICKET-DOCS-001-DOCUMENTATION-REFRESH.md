# TICKET DOCS-001: Documentation Refresh

**Component:** `docs/`, root `README.md`, `chapter2/README.md` · **Priority:** Low · **Run last** · **Read first:** `docs/tickets/README.md`

## Problem
The docs have drifted from the code:
- **Mobile status:** `docs/ARCHITECTURE.md` still says `chapter2/` is "Phase 4 … (Pending)". Its monorepo tree omits `packages/`, `backend/src/{auth,agents,blockchain,database,vendor}` and `scripts/`.
- **Persistence:** `docs/features/backend-onchain-persistence-x402.md` and `docs/tickets/TICKET-ONCHAIN-PERSISTENCE-X402.md` describe SQLite / `better-sqlite3`. The code uses Postgres plus an in-memory mirror.
- **Stale links:** many feature docs link to `file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/...`.
- **Test counts:** the counts disagree (33, 44, 59, 93, 101, 125, …).
- **Package ID:** `docs/features/mobile-scaffolding.md` and `.agents/rules/execution_discipline.md` say `io.chapter2.app`; the app uses `com.chapter2.app`.
- **Mobile README:** `chapter2/README.md` is the Flutter template.
- **Security model:** the docs describe World ID or the backend Ledger key as approval authority, and `POST /ledger/sign` as an endpoint. After the security-hardening branch, only the Chapter2Guard `humanSigner` can approve, `/ledger/sign` is gone, and most routes need a Privy bearer token.

## Implementation
1. **Links:** replace absolute `file:///…` links with repo-relative links.
2. **`docs/ARCHITECTURE.md`:** update the structure tree, deployed addresses (after PAY-001) and the trust model:
   - owner, humanSigner and autonomousAgent are distinct
   - which routes are public and which are authenticated
   - the x402 verification and replay protection
3. **Feature doc:** add `docs/features/backend-security-hardening.md` (overview, what changed, invariants, known limitations) covering the auth, ownership, World ID, Ledger, approval and x402 changes.
4. **Test counts:** remove hardcoded counts, or regenerate them from an actual `jest` run.
5. **`chapter2/README.md`:** document setup (`.env` / `--dart-define` values), flavors, and how to run against local and Render backends.
6. **Endpoint catalog:** `docs/features/agent-deployment-and-endpoint-testing.md` must mark auth requirements and drop `/ledger/sign`.

## Acceptance criteria
- **No absolute links:** no `file:///` links remain.
- **Docs match behaviour:** every documented endpoint, status and trust rule matches the code on `development` after the preceding tickets merge.
- **Commits:** docs-only commits (`docs(features): …` / `docs(repo): …`).
