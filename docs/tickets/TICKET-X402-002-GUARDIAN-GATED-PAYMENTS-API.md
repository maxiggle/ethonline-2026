# TICKET X402-002: Guardian-Gated x402 Payments API

**Lane:** B · **Time box:** 2.5 h · **Component:** `backend/` · **Depends on:** X402-001 config · **Read first:** `docs/tickets/README.md`

## Why
Before the agent signs any x402 payment, Chapter 2 must decide **ALLOW / ESCALATE / BLOCK**:
- **ALLOW** is signed by the Key Ring agent wallet (LEDGER-001).
- **ESCALATE** is signed on the human's Ledger through the approval console (LEDGER-002).
- **BLOCK** is never signed.

This API is the contract used by LEDGER-002 and X402-003. **Implement it exactly as specified.**

⚠️ This rail must **never** call `OnChainExecutorService.executeAutonomousPayment` / `executeEscalatedPayment`, because the relayer key is leaked. `verifyTokenTransfer` (read-only) is allowed.

## Existing code to reuse
- **Actions:** `ActionStoreService.createAction(dto)`, `getAction(id)`, `updateStatus(id, status, { txHash, signature })`. Store every x402 payment as a `TreasuryAction` so it shows in the existing timeline, with `justification` prefixed `x402: `.
- **Risk analysis:** `RiskAnalysisService.performMultiLayerSemanticAnalysis(text)` for adversarial justification detection. **Don't** use `evaluateAction`, because it applies the Safe mandate (hardcoded caps and recipients).
- **Agents:** `AgentsService.getAgentByAddress(address)`; status must be `ACTIVE`.
- **Events:** `EventsGateway.emitActionProposed / emitActionApproved / emitActionEscalated / emitActionBlocked / emitActionRejected / emitActionExecuted`. Check each payload type and supply what it requires.
- **Transfer check:** `OnChainExecutorService.verifyTokenTransfer(txHash, { token, recipient, minimumAmount })`.
- **Persistence:** `DatabaseService` table pattern (Postgres DDL + in-memory `querySync`/`runSync` + load + file persistence). See `x402_payment_receipts`.

## 1. Agent request authentication: `AgentSignatureGuard`
Agents authenticate with their Key Ring-protected key, not a Privy token.
- Enable raw body: `NestFactory.create(AppModule, { rawBody: true })`.
- **Headers:** `X-Agent-Address`, `X-Agent-Timestamp` (unix seconds) and `X-Agent-Signature`. The signature is EIP-191 `personal_sign` of this message:
  ```
  chapter2-agent-request
  <HTTP METHOD uppercase>
  <request path including query string>
  <timestamp>
  <sha256 hex of the raw request body, or of the empty string>
  ```
- **Checks:**
  - timestamp within ±60 s of server time;
  - the recovered address equals `X-Agent-Address`;
  - the agent exists and is `ACTIVE`;
  - the signature hasn't been used before (in-memory set pruned after 120 s).

  Reject with `401`. Attach `request.agent` (the agent record).
- **Tests:** valid request, stale timestamp, tampered body, wrong signer, replayed signature, unknown or inactive agent.

## 2. Spending policy: `X402SpendingPolicyService`
- **Env:** `X402_NETWORK`, `USDC_ADDRESS`, `X402_APPROVED_PAY_TO` (comma-separated), `X402_AUTONOMOUS_LIMIT`, `X402_DAILY_LIMIT` (atomic units). All are required.
- **Deterministic rules, in order:**
  1. `network !== X402_NETWORK` → BLOCK.
  2. `asset !== USDC_ADDRESS` (case-insensitive) → BLOCK.
  3. `payTo` not in the approved list → BLOCK.
  4. `amount > X402_AUTONOMOUS_LIMIT` → ESCALATE.
  5. Today's (UTC) total of this agent's x402 actions in `APPROVED`/`EXECUTED` plus `amount` exceeds `X402_DAILY_LIMIT` → ESCALATE.
- **Semantic layer:** run `performMultiLayerSemanticAnalysis(justification)`. If it flags adversarial intent, raise ALLOW to ESCALATE. The semantic layer can only elevate, never downgrade.
- **Result:** `{ decision, riskScore (0–100), reasons: string[] }`.
- **Tests:** each rule, the adversarial elevation, and that the semantic layer never downgrades a BLOCK or ESCALATE.

## 3. Persistence: `x402_escalations` table
Columns: `action_id` PK, `resource_url`, `typed_data` (JSON text), `signature` nullable, `status` (`AWAITING_SIGNATURE` | `SIGNED` | `REJECTED`), `created_at`, `updated_at`. Follow the `DatabaseService` pattern.

## 4. Endpoints: `X402PaymentsController`

### Agent endpoints (`AgentSignatureGuard`)
| Method & path | Body | Behaviour | Response |
|---|---|---|---|
| `POST /x402/payments/authorize` | `{ resourceUrl, paymentRequirements: { scheme, network, asset, amount, payTo }, justification }` | Validate the DTO (class-validator). Create a `TreasuryAction` (`token=asset`, `target=asset`, `recipient=payTo`, `amount`, `agentAddress=request.agent.agentAddress`, `value='0'`, `data='0x'`, `justification='x402: ' + resourceUrl + ' | ' + justification`) and evaluate the policy. The status becomes APPROVED for ALLOW, PENDING for ESCALATE and REJECTED for BLOCK. Emit the matching event. | `{ actionId, decision, riskScore, reasons }` |
| `POST /x402/payments/:actionId/escalation` | `{ typedData }` (the EIP-3009 typed data the x402 client asks the Ledger account to sign) | See the escalation checks below. On success, store `AWAITING_SIGNATURE` and emit `emitActionEscalated`. | `{ actionId, status }` |
| `GET /x402/payments/:actionId` | none | The action must belong to the agent. | `{ actionId, decision, actionStatus, escalationStatus?, signature? }` |
| `POST /x402/payments/:actionId/settlement` | `{ transactionHash }` (from the decoded `PAYMENT-RESPONSE`) | The action must belong to the agent and be `APPROVED`. Verify with `verifyTokenTransfer(transactionHash, { token: action.token, recipient: action.recipient, minimumAmount: BigInt(action.amount) })`, then mark the action `EXECUTED` with the `txHash` and emit `emitActionExecuted`. Reject with 400 if verification fails. | `{ actionId, status: 'EXECUTED', transactionHash }` |

**Escalation checks** for `POST /x402/payments/:actionId/escalation`:
- the action belongs to the agent and is `PENDING`;
- `primaryType === 'TransferWithAuthorization'`;
- `domain.verifyingContract == USDC_ADDRESS`, `domain.chainId == 84532`;
- `message.from == LEDGER_APPROVER_ADDRESS`, `message.to == action.recipient`, `message.value == action.amount`;
- `message.validBefore` is in the future.

### Approval console endpoints (public; authority is the Ledger signature itself)
| Method & path | Body | Behaviour |
|---|---|---|
| `GET /x402/approvals/config` | none | Return `{ approverAddress: LEDGER_APPROVER_ADDRESS, network, usdcAddress }`. |
| `GET /x402/approvals/pending` | none | Return escalations in `AWAITING_SIGNATURE`: `{ actionId, resourceUrl, amount, payTo, agentAddress, justification, riskScore, reasons, typedData, createdAt }`. |
| `POST /x402/approvals/:actionId/signature` | `{ signature }` | Recover with ethers `verifyTypedData(domain, types without EIP712Domain, message, signature)`. It must equal `LEDGER_APPROVER_ADDRESS` (checksum-compare), else 401. On success mark the escalation `SIGNED` and store the signature, set the action `APPROVED` (with `signature`), and emit `emitActionApproved`. |
| `POST /x402/approvals/:actionId/reject` | `{ signature }` | `signature` is EIP-191 `personal_sign` of `chapter2-reject:<actionId>` and must recover to `LEDGER_APPROVER_ADDRESS`. Mark the escalation `REJECTED`, set the action `REJECTED`, and emit `emitActionRejected`. |

Add `LEDGER_APPROVER_ADDRESS` to the required config. Document the security rationale in a short comment: public endpoints can only read pending payment details, and every state change needs the Ledger's signature.

## Tests (mock the executor; never broadcast)
- **Authorize:** ALLOW, ESCALATE and BLOCK paths set the right statuses and events, and `executeAutonomousPayment` / `executeEscalatedPayment` are **never called**.
- **Escalation:** each rejected mismatch (from, to, value, token, chain, expired).
- **Approval signature:**
  - Build real typed data, sign it with an ethers `Wallet` whose address is `LEDGER_APPROVER_ADDRESS`, and expect it accepted.
  - A different wallet is rejected.
  - A tampered message is rejected.
- **Reject:** signature verification.
- **Settlement:** a verified transfer gives `EXECUTED`; a failed verification gives 400 and the status stays `APPROVED`.

## Acceptance criteria
- **Contract:** every endpoint above works as specified.
- **Gate:** the backend gate passes.
- **Safety:** no path can move funds through the relayer, and every approval of an escalated payment is backed by a signature that recovers to `LEDGER_APPROVER_ADDRESS`.
- **Commits** (for example):
  - `feat(backend): authenticate agent requests with signed headers`
  - `feat(backend): add x402 spending policy`
  - `feat(backend): add Guardian-gated x402 payment authorization and Ledger escalation API`
