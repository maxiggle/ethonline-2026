# Feature Documentation: Guardian-Gated x402 Payments API

## 1. Overview
Ticket `X402-002` gives the AI agent a way to have Chapter 2 decide **ALLOW / ESCALATE / BLOCK**
before it ever signs an x402 v2 payment. ALLOW is meant to be signed by the agent's own Key Ring
wallet (LEDGER-001); ESCALATE is signed on the human's Ledger through the web approval console
(LEDGER-002); BLOCK is never signed by anyone. This ticket's API is the fixed contract those two
lanes build against — implemented exactly as specified so they can be built in parallel.

This rail **never** calls `OnChainExecutorService.executeAutonomousPayment` /
`executeEscalatedPayment` (the relayer key is leaked); it only ever uses the read-only
`verifyTokenTransfer` to confirm a settlement actually happened on-chain.

## 2. How It Was Built

### Agent authentication (`x402/guards/agent-signature.guard.ts`)
Agents authenticate with their Key Ring-protected wallet key, not a Privy token.
`AgentSignatureGuard` recovers the EIP-191 `personal_sign` signer of:
```
chapter2-agent-request
<HTTP METHOD uppercase>
<request path including query string>
<timestamp>
<sha256 hex of the raw request body, or of the empty string>
```
from `X-Agent-Signature`, checks it equals `X-Agent-Address`, that `X-Agent-Timestamp` is within
±60s, that the signature hasn't been used before (in-memory set, pruned after 120s), and that the
address is an `ACTIVE` agent — then attaches the agent record as `request.agent`. `main.ts` enables
`rawBody: true` so the guard hashes the exact bytes the client sent, not a re-serialized copy.

### Spending policy (`x402/x402-spending-policy.service.ts`)
Deterministic rules, in order, independent of the legacy Safe mandate (`PolicyEngineService`):
network match → USDC asset match → approved `payTo` → `amount > X402_AUTONOMOUS_LIMIT` (ESCALATE) →
today's UTC total of this agent's `x402:`-prefixed `APPROVED`/`EXECUTED` actions plus `amount` over
`X402_DAILY_LIMIT` (ESCALATE). A semantic-analysis pass
(`RiskAnalysisService.performMultiLayerSemanticAnalysis`) can only elevate an ALLOW to ESCALATE,
never downgrade a BLOCK or ESCALATE.

### Persistence (`x402_escalations` table)
Follows the existing `DatabaseService` table pattern (Postgres DDL + in-memory `querySync`/`runSync`
+ load + file persistence), storing `action_id` (PK), `resource_url`, `typed_data` (JSON text),
`signature`, `status` (`AWAITING_SIGNATURE | SIGNED | REJECTED`) and timestamps. Every x402 payment
is also a `TreasuryAction` (`justification` prefixed `x402: <resourceUrl> | <reason>`), so it shows
in the existing activity timeline for free.

### Endpoints (`x402-payments.{controller,service}.ts`)

**Agent-authenticated** (`AgentSignatureGuard`):
| Method & path | Behaviour |
|---|---|
| `POST /x402/payments/authorize` | Creates the `TreasuryAction`, runs the spending policy, sets `APPROVED`/`PENDING`/`REJECTED` and emits the matching `EventsGateway` event. Returns `{ actionId, decision, riskScore, reasons }`. |
| `POST /x402/payments/:actionId/escalation` | Validates the caller's EIP-3009 `TransferWithAuthorization` typed data (`primaryType`, `domain.verifyingContract == USDC_ADDRESS`, `domain.chainId == 84532`, `message.from == LEDGER_APPROVER_ADDRESS`, `message.to == action.recipient`, `message.value == action.amount`, `message.validBefore` in the future) against the action before storing it `AWAITING_SIGNATURE` and emitting `emitActionEscalated`. |
| `GET /x402/payments/:actionId` | Ownership-checked read: `{ actionId, decision, actionStatus, escalationStatus?, signature? }`. `decision` is derived from `actionStatus` (`APPROVED`/`EXECUTED` → ALLOW, `PENDING` → ESCALATE, `REJECTED` → ESCALATE if an escalation row exists, else BLOCK). |
| `POST /x402/payments/:actionId/settlement` | Requires `APPROVED`; verifies the transaction with `verifyTokenTransfer(txHash, { token: action.token, recipient: action.recipient, minimumAmount: BigInt(action.amount) })`, then marks `EXECUTED` and emits `emitActionExecuted`. `400` on verification failure, action stays `APPROVED`. |

**Public approval console** (authority is the Ledger signature itself, not a session):
| Method & path | Behaviour |
|---|---|
| `GET /x402/approvals/config` | `{ approverAddress, network, usdcAddress }`. |
| `GET /x402/approvals/pending` | Escalations still `AWAITING_SIGNATURE`, with the stored `typedData` for the console to render and re-sign. |
| `POST /x402/approvals/:actionId/signature` | Recovers with `ethers.verifyTypedData(domain, types-without-EIP712Domain, message, signature)`; must checksum-equal `LEDGER_APPROVER_ADDRESS`. Marks the escalation `SIGNED`, the action `APPROVED` (with the signature), and emits `emitActionApproved`. |
| `POST /x402/approvals/:actionId/reject` | `signature` must be an EIP-191 `personal_sign` of `chapter2-reject:<actionId>` recovering to `LEDGER_APPROVER_ADDRESS`. Marks the escalation `REJECTED`, the action `REJECTED`, and emits `emitActionRejected`. |

These console endpoints can only ever read pending payment details; every state change requires a
signature that recovers to the configured Ledger address, so exposing them without a session is safe
by construction.

## 3. Data Flow & Interfaces
```
Agent → POST /x402/payments/authorize (signed headers) → { actionId, decision: ESCALATE, ... }
Agent → POST /x402/payments/:actionId/escalation { typedData } → { status: AWAITING_SIGNATURE }
Console → GET /x402/approvals/pending → [{ actionId, typedData, ... }]
Human/Ledger → signs typedData → Console → POST /x402/approvals/:actionId/signature { signature }
  → action APPROVED
Agent → x402 client pays the resource with the signed authorization → gets a settlement tx hash
Agent → POST /x402/payments/:actionId/settlement { transactionHash } → { status: EXECUTED }
```

## 4. Trade-offs / Edge Cases
- **In-memory replay cache is per-instance.** Same class of limitation as SEC-004's receipts table:
  fine for a single backend instance (tonight's demo), not for a horizontally-scaled deployment.
- **`decision` is derived, not stored.** `TreasuryAction`/`ActionStoreService` has no column for the
  original Guardian decision; `getPaymentStatus` reconstructs it from `actionStatus` plus whether an
  escalation row exists. `riskScore`/`requiresHumanApproval` are mutated in-memory on the action
  object at authorize time (same convention the legacy `ActionsController.proposeAction` already
  uses) and are not written back to the `treasury_actions` table by `ActionStoreService.updateStatus`.
- **`reasons` on `/x402/approvals/pending` are not the original policy reasons** — the
  `x402_escalations` schema (fixed by the ticket) has no column for them, so the console gets a
  generic "escalated for human approval" reason instead of the specific rule that triggered it.
- **No cross-action replay guard on settlement**, unlike the legacy `/vendor/*` rail's
  `x402_payment_receipts`: a `transactionHash` is checked against exactly one action's
  token/recipient/amount, but two coincidentally-identical actions could both be settled from the one
  real transfer. Out of this ticket's explicit scope.
- **Verified so far:** the full backend gate (`tsc --noEmit` + `jest`) and a live boot confirming the
  full route table registers and the app starts with no missing providers. Full live HTTP
  authorize→escalate→approve→settle verification needs a real Privy-bound agent and Ledger signer,
  which is X402-003's job.
