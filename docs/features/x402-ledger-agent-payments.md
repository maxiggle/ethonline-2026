# Feature Documentation: x402 + Ledger Agent Payments

## 1. Overview
An autonomous agent pays for real x402 v2 resources with Base Sepolia USDC. The Chapter 2 Guardian decides **ALLOW / ESCALATE / BLOCK** before any payment signature exists:

| Decision | Who signs the EIP-3009 `TransferWithAuthorization` | Paid from |
|---|---|---|
| ALLOW | The agent wallet. Its key is decrypted from the **Ledger Key Ring** (`wallet-cli ring`) into memory only | Agent address |
| ESCALATE | The human, **on their Ledger** (Nano X / Flex), through the mobile app over Bluetooth or the WebHID approval console | `LEDGER_APPROVER_ADDRESS` |
| BLOCK | Nobody | n/a |

The public x402 facilitator settles every payment. The backend then confirms the USDC `Transfer` on-chain before marking the `TreasuryAction` `EXECUTED`.

The feature combines five tickets:

| Ticket | Component | Detailed doc |
|---|---|---|
| LEDGER-001 | Key Ring-protected agent wallet | `scripts/lib/ledger-key-ring.ts`, `scripts/lib/agent-account.ts` |
| X402-001 | x402 v2 seller endpoints | [x402-v2-seller.md](x402-v2-seller.md) |
| X402-002 | Guardian-gated payments API | [x402-guardian-payments-api.md](x402-guardian-payments-api.md) |
| LEDGER-002 | Ledger approval console | [`approval-console/README.md`](../../approval-console/README.md) |
| X402-003 | Agent demo client | `scripts/agent-x402-client.ts` |

## 2. How It Was Built

### Agent wallet (Ledger Key Ring)
- **Provisioning (human):** `wallet-cli ring init` provisions the ring, which needs the device. A fresh key from `cast wallet new` is piped straight into `wallet-cli ring encrypt -o ~/.chapter2/agent-key.enc --key chapter2-x402-agent`, so the plaintext key never touches disk.
- **Loading:** `decryptWithLedgerKeyRing` spawns `wallet-cli ring decrypt` with `shell: false`, requires `WALLET_PASS` from the environment (read from the macOS Keychain at launch), and validates that stdout is a 32-byte key. `loadAgentAccount()` wraps the key in a viem account. Errors never include the key.

### Agent request authentication
Agents don't use Privy tokens. Each request to `/x402/payments/*` carries `X-Agent-Address`, `X-Agent-Timestamp` and `X-Agent-Signature`, where the signature is an EIP-191 `personal_sign` over:
```
chapter2-agent-request
<METHOD>
<path including query string>
<unix timestamp>
<sha256 hex of the exact raw body>
```
`AgentSignatureGuard` checks:
- the signature recovers to `X-Agent-Address`;
- the timestamp is within ±60 s;
- the signature hasn't been used before;
- the address belongs to an `ACTIVE` bound agent.

### Spending policy
`X402SpendingPolicyService` is deterministic and independent of the legacy Safe mandate. Rules run in order:
1. **BLOCK** if the network isn't `eip155:84532`.
2. **BLOCK** if the asset isn't the configured USDC.
3. **BLOCK** if `payTo` isn't in `X402_APPROVED_PAY_TO`.
4. **ESCALATE** if `amount > X402_AUTONOMOUS_LIMIT`.
5. **ESCALATE** if today's approved or executed x402 total plus `amount` exceeds `X402_DAILY_LIMIT`.

A semantic pass over the justification can raise ALLOW to ESCALATE, never lower a decision.

### Escalation typed-data checks
Before the human ever sees an escalation, the backend checks the agent-submitted typed data against the Guardian's own record of the action:
- `primaryType` is `TransferWithAuthorization`;
- `domain.verifyingContract` is USDC and `domain.chainId` is `84532`;
- `message.from` is the Ledger approver, `message.to` is the action's payee, and `message.value` is the action's amount;
- `message.validBefore` is in the future.

The approval signature is recovered with `verifyTypedData` and must equal `LEDGER_APPROVER_ADDRESS`. The authorization must still be unexpired at approval time. Rejections are a `personal_sign` of `chapter2-reject:<actionId>` from the same address.

### Approval console
A Vite app using Ledger DMK over WebHID:
1. Connects the device and reads `44'/60'/0'/0/0`.
2. Refuses to approve if that address isn't the backend's `approverAddress`.
3. Polls `/x402/approvals/pending` and shows resource, amount, payee, agent, risk score, policy reasons and expiry.
4. Signs the stored typed data on the device.

### Demo client
For each resource the agent:
1. Requests it and decodes the `402` requirements.
2. Asks the Guardian (`POST /x402/payments/authorize`).
3. Builds the x402 payment payload with the signer the decision selects: the Key Ring account for ALLOW, a remote Ledger signer that submits typed data and waits for the console signature for ESCALATE, and nothing for BLOCK.
4. Retries the request with `PAYMENT-SIGNATURE`.
5. Reports the `PAYMENT-RESPONSE` tx hash to `POST /x402/payments/:id/settlement`.

Exactly one Guardian authorization happens per payment.

## 3. Data Flow & Interfaces
```
Agent → GET /x402/chain-report                      → 402 PAYMENT-REQUIRED ($2.00, payTo, USDC, maxTimeoutSeconds 900)
Agent → POST /x402/payments/authorize (signed)      → { actionId, decision: ESCALATE, riskScore, reasons }
Agent → POST /x402/payments/:id/escalation (signed) → { status: AWAITING_SIGNATURE }   (typed data checked)
Console → GET /x402/approvals/pending               → [{ actionId, typedData, reasons, ... }]
Ledger → signs TransferWithAuthorization on device
Console → POST /x402/approvals/:id/signature        → { status: SIGNED }   (must recover to LEDGER_APPROVER_ADDRESS)
Agent → GET /x402/payments/:id (signed, polled)     → { escalationStatus: SIGNED, signature }
Agent → GET /x402/chain-report + PAYMENT-SIGNATURE  → facilitator settles → 200 + PAYMENT-RESPONSE (tx hash)
Agent → POST /x402/payments/:id/settlement (signed) → verifyTokenTransfer → { status: EXECUTED }
```
For ALLOW, the escalation, console and polling steps are skipped and the agent signs locally. For BLOCK, the flow stops after `authorize`.

## 4. Trade-offs / Edge Cases
- **Authorization window.** The x402 client sets `validBefore = now + maxTimeoutSeconds`. The escalated `chain-report` route advertises 900 s. An approval after expiry is refused, because the facilitator couldn't settle it; the agent must request again.
- **No relayer.** The rail never calls `OnChainExecutorService` execution methods, only the read-only `verifyTokenTransfer`. The facilitator pays gas, so neither the agent nor the Ledger address needs ETH.
- **Single-instance state.** The agent-signature replay cache and the escalation reasons held between `authorize` and `escalation` are per process. That's fine for one backend instance, not for horizontal scaling.
- **No cross-action settlement replay guard.** A transaction hash is verified against one action's token, payee and minimum amount, but isn't marked as consumed across actions.
- **Public console reads.** `/x402/approvals/pending` exposes pending payment details without a session. Every state change requires a Ledger signature, so the endpoint grants no authority.
- **Origin token.** Without `VITE_LEDGER_ORIGIN_TOKEN` the console still works, with reduced Ledger-side transaction checks. No value is ever invented.
- **World ID gate not enforced.** Approvals require the Ledger signature only. Requiring an active World ID Selfie Check binding for the approver is designed ([world-id-approval-gate.md](../world-id-approval-gate.md)) but waits on World approving Selfie Check access.
