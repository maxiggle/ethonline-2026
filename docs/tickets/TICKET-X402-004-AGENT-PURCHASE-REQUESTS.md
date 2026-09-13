# TICKET X402-004: Purchase Requests from the App, Paid by the Agent Worker

**Time box:** 2.5 h · **Components:** `backend/`, `scripts/` · **Depends on:** X402-002, X402-003 (done) · **Read first:** `docs/tickets/README.md`, `AGENTS.md`, `.agents/rules/*.md` · **Parallel lane:** MOBILE-003 builds the app side against the contract below

## Why
A company operator browses x402 services in the app (Bazaar discovery, `GET /discovery/resources`) and asks their agent to buy one.

**Who holds the key:** the agent's key lives only on the agent machine, behind the Ledger Key Ring, so the backend and the app must never sign.

**How it works:**
1. The app **queues a purchase request**.
2. The agent **worker** claims it.
3. The worker pays through the existing Guardian-gated flow (`payX402Resource`: ALLOW / ESCALATE to Ledger / BLOCK).
4. The worker reports the progress and the result back.
5. The app shows the status and the paid response data.

**Rules for this ticket:**
- **Legacy rail:** don't use or extend `POST /discovery/call` or anything that touches `OnChainExecutorService` execution. That is the legacy relayer rail.
- **Settlement check:** `verifyTokenTransfer` stays the only on-chain call, and it's already run by `/x402/payments/:id/settlement`.

## API contract (fixed; MOBILE-003 depends on it)

### Purchase request object (JSON)
```json
{
  "id": "pr_…",
  "agentAddress": "0x…",
  "serviceName": "Open-Meteo Weather Oracle",
  "resourceUrl": "https://chapter2-backend.onrender.com/x402/weather",
  "queryParams": { "city": "Lagos" },
  "justification": "…",
  "amount": "10000",
  "status": "QUEUED | PROCESSING | AUTHORIZED | PAID | BLOCKED | REJECTED | EXPIRED | FAILED",
  "actionId": "act_… | null",
  "decision": "ALLOW | ESCALATE | BLOCK | null",
  "reasons": ["…"],
  "transactionHash": "0x… | null",
  "response": { },
  "error": "… | null",
  "createdAt": "ISO-8601",
  "updatedAt": "ISO-8601"
}
```

- `serviceName` and `amount` (USDC atomic units) are copied from the catalog entry when the request is created.
- `response` is the paid resource's JSON body, or `null`.

### App endpoints (`PrivyAuthGuard`)

**`POST /x402/purchase-requests`**, body `{ agentAddress, resourceUrl, queryParams, justification }`.
- `agentAddress` must be owned by the caller, checked with `AgentsService.assertAgentOwnership`.
- `resourceUrl` must equal the `resource` of an entry in `VendorService.getBazaarCatalog()`.
- Every `queryParams` key must exist in that entry's `extensions.bazaar.info.input.queryParams`. Values must be non-empty strings of at most 100 characters.
- `justification` must be non-empty, at most 280 characters.
- Creates the request with status `QUEUED` and returns it (`201`).

**`GET /x402/purchase-requests`** returns the caller's requests, newest first, up to 50.

**`GET /x402/purchase-requests/:id`** returns one request; `404` if it isn't the caller's.

### Agent worker endpoints (`AgentSignatureGuard`, same signed-header scheme as `/x402/payments/*`)

**`POST /x402/purchase-requests/claim`**, empty body.
- Atomically moves the oldest `QUEUED` request for `request.agent.agentAddress` to `PROCESSING` and returns it.
- Returns `204` when there's nothing to claim.

**`POST /x402/purchase-requests/:id/progress`**, body `{ actionId, decision, reasons }`.
- Only from the claiming agent, and only when the request is `PROCESSING`.
- `actionId` must exist in `ActionStoreService`, belong to that agent, and carry `x402: <resourceUrl…>` in its justification. Matching on a prefix of the URL is fine, because query strings are allowed.
- Sets `AUTHORIZED` with `actionId`, `decision` and `reasons`.

**`POST /x402/purchase-requests/:id/result`**, body `{ status: PAID|BLOCKED|REJECTED|EXPIRED|FAILED, actionId?, decision?, reasons?, transactionHash?, response?, error? }`.
- Only from the claiming agent, and only when the request is `PROCESSING` or `AUTHORIZED`.
- **`PAID`** requires an `actionId` owned by the agent whose `TreasuryAction` is `EXECUTED` with a `txHash` equal to `transactionHash`, compared case-insensitively. That makes backend state the source of truth, not the client's claim. Otherwise return `400`.
- **`BLOCKED`** requires `decision === 'BLOCK'`.
- **`response`:** store it only if its JSON is at most 32 KB; otherwise `400`.
- Terminal states are final, so a later call returns `409`.

## Implementation

### Backend (`backend/src/x402/`)
1. **Table `x402_purchase_requests`:**
   - Follow the `x402_escalations` pattern exactly: Postgres DDL, in-memory `querySync`/`runSync` branches, load-from-Postgres, and file persistence in `database.service.ts` plus a row interface in `database.interface.ts`.
   - Columns mirror the object: JSON text for `query_params`, `reasons` and `response`; plus `user_id`.
   - Add a database spec for insert, claim transition and result update.
2. **`X402PurchaseRequestsService` + `X402PurchaseRequestsController`**, wired in `x402.module.ts`.
   - Import what's needed: `AgentsModule` / `VendorModule` exports, or the existing providers; check how `x402.module.ts` already gets `AgentsService`.
   - **Claim is atomic:** do it in one service method under a per-agent in-memory lock, a promise chain keyed by agent address, so two workers can't claim the same request.
   - **Events:** emit through `EventsGateway` if a suitable event exists. Otherwise skip it; don't add websocket contracts.
3. **Controller spec:**
   - validation (unknown resource, unknown param key, oversize justification);
   - ownership (another user's agent → 403, another user's request → 404);
   - claim ordering, and `204` when empty;
   - progress checks (wrong agent, foreign `actionId`);
   - result `PAID` accepted only when the action is `EXECUTED` with a matching hash;
   - `409` after a terminal state;
   - the response size cap.

### Agent worker (`scripts/`)
1. **Refactor** `scripts/lib/x402-payment-flow.ts`: add an optional `onAuthorized?(authorization: AuthorizePaymentResponse) => Promise<void>` to `payX402Resource`, called right after `authorizePayment`, before signing. Keep the existing tests green and add one for the hook.
2. **`scripts/lib/purchase-requests.ts`:** `claimPurchaseRequest`, `reportProgress` and `reportResult`, all via `signedAgentFetch`.
3. **`scripts/agent-worker.ts`,** plus `"agent:worker": "tsx agent-worker.ts"` in `scripts/package.json`.
   - **Env:** same as the demo (`API_BASE_URL`, `AGENT_KEY_SOURCE` and its per-source variables).
   - **Setup:** load the agent account once and fetch `/x402/approvals/config`.
   - **Loop:** claim; if `204`, wait 5 s.
   - **Handling one request:**
     1. Require `resourceUrl` to start with `API_BASE_URL`. Otherwise report `FAILED` with "resource is not on this backend".
     2. Build `resourcePath` as the path plus a query string from `queryParams` (URL-encoded).
     3. Call `payX402Resource` with `onAuthorized` calling `reportProgress`.
     4. Report the outcome: `PAID` with `transactionHash` and `response` = data; `BLOCKED` with reasons; `REJECTED` if the Ledger rejection error is thrown; `EXPIRED` on the validBefore timeout error; `FAILED` with the error message for anything else.
   - **Output:** narrated console lines per request, same style as the demo client.
   - **Shutdown:** on SIGINT, finish the current request, then exit.
4. **Tests (vitest, mocked fetch):**
   - query-string building;
   - `onAuthorized` reporting;
   - PAID, BLOCKED, REJECTED, EXPIRED and FAILED reporting;
   - rejecting a non-matching `resourceUrl`.

### Docs
- **`docs/features/x402-agent-purchase-requests.md`:** Overview, How It Was Built, Data Flow & Interfaces, Trade-offs.
- **README:** a short "Buy a service from the app" section with the worker command.

## Gates
- **Backend:** `cd backend && npx tsc --noEmit -p tsconfig.json && npx jest --runInBand --forceExit --testPathIgnorePatterns on-chain-executor.service.spec`.
- **Scripts:** `npm --prefix scripts run typecheck && npm --prefix scripts test`.

## Commits
- Scopes `backend`, `client`, `docs`; a 1–3 bullet body; **no `Co-Authored-By` trailer**.
- Explicit paths only. Never push or amend.
- Keep each commit to at most 2–3 closely related files where practical.

## Acceptance criteria
- **App → agent flow:** with the worker running against the live backend, a request created with `POST /x402/purchase-requests` for `/x402/weather` (`city`) goes `QUEUED` → `PROCESSING` → `AUTHORIZED` → `PAID`, with a real Base Sepolia `transactionHash` and the weather JSON in `response`.
- **Escalation and block:** a `/x402/chain-report` request stops at `AUTHORIZED` (ESCALATE) until Ledger approval, and a `/x402/partner-feed` request ends `BLOCKED`.
