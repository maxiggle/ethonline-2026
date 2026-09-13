# Feature Documentation: Purchase Requests from the App, Paid by the Agent Worker

## 1. Overview
Ticket `X402-004` lets a company operator browse x402 services in the app (Bazaar discovery,
`GET /discovery/resources`) and ask their agent to buy one, without the app or the backend ever
touching the agent's key. The app queues a purchase request; a separate agent worker process
claims it, pays it through the existing Guardian-gated x402 flow from `X402-002`/`X402-003`
(ALLOW / ESCALATE to Ledger / BLOCK), and reports progress and the final result back so the app
can show status and the paid response data.

This rail never uses `POST /discovery/call` or any `OnChainExecutorService` execution method (the
legacy relayer rail); `verifyTokenTransfer`, already run by `/x402/payments/:id/settlement`, stays
the only on-chain read.

## 2. How It Was Built

### Persistence (`x402_purchase_requests` table)
Follows the `x402_escalations` pattern exactly in `database.service.ts`/`database.interface.ts`:
Postgres DDL, in-memory `querySync`/`runSync` branches, load-from-Postgres and file persistence.
Columns mirror the API object 1:1, with JSON text for `query_params`, `reasons` and `response`,
plus a `user_id` column (not part of the API response) that scopes `GET /x402/purchase-requests`
and `:id` to the caller. The claim transition is a single conditional `UPDATE ... WHERE id = ? AND
status = 'QUEUED'`, so `runSync` reports `changes: 0` if another writer already claimed the row.

### Service (`x402-purchase-requests.service.ts`)
- **Creation** validates ownership (`AgentsService.assertAgentOwnership`), resolves the catalog
  entry from `VendorService.getBazaarCatalog()` by exact `resource` match, validates every
  `queryParams` key against that entry's `extensions.bazaar.info.input.queryParams` (non-empty
  string, ≤100 chars), and copies `serviceName`/`amount` from the catalog rather than trusting the
  client.
- **Claim is atomic** two ways: a per-agent-address `Promise` chain (`claimLocks`) serializes every
  `claim()` call for the same agent so two workers authenticated as the same agent can never both
  read the same "oldest QUEUED" row before either writes; the conditional
  `WHERE status = 'QUEUED'` update is the second line of defense if that in-memory chain were ever
  bypassed (e.g. a second backend instance).
- **Progress** requires the request to be `PROCESSING`, resolves `actionId` through
  `ActionStoreService.getAction`, checks it belongs to the reporting agent, and checks its
  `justification` (`x402: <resourceUrl-with-query> | ...`) starts with the purchase request's
  (query-string-free) `resourceUrl` — a prefix match, because the worker pays the resource with its
  query string appended.
- **Result** requires `PROCESSING` or `AUTHORIZED`; a request already in a terminal status
  (`PAID`/`BLOCKED`/`REJECTED`/`EXPIRED`/`FAILED`) throws `409`. `PAID` is verified against backend
  state (see §3). `BLOCKED` requires `decision === 'BLOCK'`. `response` is capped at 32 KB of JSON.

### Circular module dependency (`x402.module.ts` ↔ `vendor.module.ts`)
`VendorModule` already imports `X402Module` for `X402_CONFIG`; `X402PurchaseRequestsService` now
also needs `VendorService.getBazaarCatalog()`. Both module `imports` use `forwardRef()` for the
other side, and the service injects `VendorService` with
`@Inject(forwardRef(() => VendorService))` — the standard NestJS pattern for a genuine two-way
module dependency.

### Endpoints (`x402-purchase-requests.{controller,service}.ts`)

**App-authenticated** (`PrivyAuthGuard`):
| Method & path | Behaviour |
|---|---|
| `POST /x402/purchase-requests` | Creates the request `QUEUED`, `201`. |
| `GET /x402/purchase-requests` | The caller's requests, newest first, capped at 50. |
| `GET /x402/purchase-requests/:id` | `404` unless it belongs to the caller. |

**Agent-authenticated** (`AgentSignatureGuard`, same signed-header scheme as `/x402/payments/*`):
| Method & path | Behaviour |
|---|---|
| `POST /x402/purchase-requests/claim` | Atomically claims the oldest `QUEUED` request for the calling agent; `200` with the row, or `204` when there's nothing to claim. |
| `POST /x402/purchase-requests/:id/progress` | Sets `AUTHORIZED` with `actionId`, `decision`, `reasons`. |
| `POST /x402/purchase-requests/:id/result` | Sets a terminal status (or `BLOCKED`), verified as described below. |

### Agent worker (`scripts/agent-worker.ts`, `scripts/lib/purchase-requests.ts`)
- `payX402Resource` (`scripts/lib/x402-payment-flow.ts`) gained an optional
  `onAuthorized?(authorization) => Promise<void>` hook, called immediately after `authorizePayment`
  resolves and before `resolvePaymentSigner` picks a signer — so it fires for every decision,
  including `BLOCK`, before any signer is ever touched.
- `agent-worker.ts` loops: `claimPurchaseRequest` (wait 5s on `204`) → build the resource path
  (`buildResourcePath`, throws if `resourceUrl` doesn't start with `API_BASE_URL`) → `payX402Resource`
  with `onAuthorized` wired to `reportProgress` → report the outcome (`reportResult`). `SIGINT`
  finishes the in-flight request before exiting.
- Error classification (`classifyWorkerError`) matches `ledger-remote-signer.ts`'s exact thrown
  messages: `/rejected by the human approver/` → `REJECTED`, `/validBefore window elapsed/` →
  `EXPIRED`, anything else → `FAILED`.

## 3. Data Flow & Interfaces
```
App    → POST /x402/purchase-requests { agentAddress, resourceUrl, queryParams, justification }
       → { id, status: QUEUED, serviceName, amount, ... }
Worker → POST /x402/purchase-requests/claim (signed headers, empty body)
       → { id, status: PROCESSING, ... } | 204
Worker → payX402Resource(...) → authorizePayment() → onAuthorized(authorization)
Worker → POST /x402/purchase-requests/:id/progress { actionId, decision, reasons }
       → { status: AUTHORIZED, ... }
Worker → (ALLOW: signs directly | ESCALATE: waits on the Ledger console | BLOCK: no signature)
Worker → POST /x402/purchase-requests/:id/result { status: PAID, actionId, transactionHash, response }
       → { status: PAID, transactionHash, response, ... }
App    → GET /x402/purchase-requests/:id → watches QUEUED → PROCESSING → AUTHORIZED → PAID
```

### How `PAID` is verified against backend state
`reportResult` never trusts the worker's claim of success. A `PAID` result requires `actionId` and
`transactionHash`, then looks the action up via `ActionStoreService.getAction(actionId)` and checks,
all against stored `TreasuryAction` state:
1. the action belongs to the reporting agent (`agentAddress` match);
2. `action.status === TreasuryActionStatus.EXECUTED` — set only by
   `X402PaymentsService.settle()` after `verifyTokenTransfer` confirmed the on-chain USDC transfer;
3. `action.txHash` equals the reported `transactionHash`, compared case-insensitively.

Any mismatch — wrong agent, action not yet `EXECUTED`, or a different hash — is a `400`, not a
silent acceptance of the client's word.

## 4. Trade-offs / Edge Cases
- **Single-instance atomicity.** The claim lock is an in-memory `Map` keyed by agent address, so it
  only serializes claims within one backend process. The conditional `WHERE status = 'QUEUED'`
  update still prevents a double-claim across processes sharing the same Postgres, at the cost of
  one worker occasionally getting a `204` it could otherwise have claimed — acceptable for tonight's
  single-instance demo, same class of limitation already documented for the escalation replay cache.
- **No new WebSocket events.** `EventsGateway` has no purchase-request-shaped event; per the ticket,
  none was added rather than inventing a new websocket contract. The app polls `GET
  /x402/purchase-requests/:id`.
- **`userId` is not in the API response.** It's stored to scope the app-facing list/get endpoints
  but deliberately excluded from the JSON shape, which the ticket fixed for the mobile lane.
- **Progress can be reported for a `BLOCK` decision.** `POST .../progress` always transitions
  `PROCESSING` → `AUTHORIZED` regardless of the Guardian's decision (ALLOW/ESCALATE/BLOCK), because
  it only records that authorization happened; `POST .../result` with `status: BLOCKED` (requiring
  `decision === 'BLOCK'`) is what makes a blocked request terminal. This matches the acceptance
  criteria (`/x402/partner-feed` ends `BLOCKED`) but means `AUTHORIZED` is momentarily visible for a
  request that is about to be blocked.
- **Verified so far:** the full backend gate (`tsc --noEmit` + `jest`, circular-module boot included
  via the existing `x402-seller.e2e.spec.ts`) and the scripts gate (`tsc --noEmit` + `vitest`). Full
  live HTTP claim → progress → result verification against a running backend and a real Ledger
  approval needs the live worker, which per this ticket's constraints was not run here (no
  `wallet-cli`, no live worker, no Keychain access, unit tests with mocks only).
