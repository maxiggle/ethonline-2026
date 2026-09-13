# Chapter 2 × Ledger

Chapter 2 lets AI agents pay for services in USDC on their own, while humans stay in control of anything that matters. **Ledger is the physical trust anchor on both sides of that boundary:**

- **Agent layer:** the agent's wallet key is protected by the **Ledger Key Ring** (`wallet-cli ring`).
- **Management layer:** payments the Guardian escalates can only be approved by a human **signing on their Ledger**, and the backend accepts no other approval.

Project overview: [README](../../../README.md)

## 1. Ledger Key Ring protects the agent's key (agent layer)

**How it works:**
1. The agent's private key is encrypted with `wallet-cli ring encrypt`, under a Key Ring provisioned with the Ledger (`wallet-cli ring init`).
2. When the agent starts, it decrypts the key with `wallet-cli ring decrypt` and holds it in memory only.
3. The key is never written to disk in plaintext, never logged, and never sent to the backend.

**Implementation:**
- [`scripts/lib/ledger-key-ring.ts`](../../../scripts/lib/ledger-key-ring.ts): `decryptWithLedgerKeyRing`
  - spawns `wallet-cli ring decrypt` (no shell);
  - requires `WALLET_PASS` from the Keychain;
  - validates the output and never echoes the key.
- [`scripts/lib/ledger-key-ring.test.ts`](../../../scripts/lib/ledger-key-ring.test.ts): tests for success, a missing password, the CLI not installed, a non-zero exit, and malformed output.
- [`scripts/lib/agent-account.ts`](../../../scripts/lib/agent-account.ts): `loadAgentAccount` with `AGENT_KEY_SOURCE=ledger-key-ring`.
- [`scripts/agent-worker.ts`](../../../scripts/agent-worker.ts): the agent worker that pays purchase requests with the Key Ring-protected key.
- [`scripts/agent-x402-client.ts`](../../../scripts/agent-x402-client.ts): the scripted ALLOW / ESCALATE / BLOCK demo.

## 2. Humans approve big payments on the Ledger (management layer)

When the Guardian escalates a payment, the agent can't sign it. The payment's USDC authorization (EIP-3009 `TransferWithAuthorization`) must be signed on the human's Ledger. The payment is then made from the Ledger address.

### Mobile app over Bluetooth (Nano X / Flex)
- **Transport:** built on `ledger_flutter_plus`.
- **Ethereum app commands, written by hand:**
  - `GET ADDRESS`;
  - `SIGN EIP-712` in hashed mode, to approve;
  - `SIGN PERSONAL MESSAGE` in chunks, to reject.
- **Hashing:** EIP-712 hashing is implemented in Dart and checked against ethers-generated test vectors.
- **Approver check:** the app confirms the connected Ledger's address matches the backend's approver before allowing any approval.

**Implementation:**
- [`ledger_ethereum_operations.dart`](../../../chapter2/lib/features/x402_approvals/ledger/ledger_ethereum_operations.dart): APDU encoding and response parsing.
- [`ledger_ble_client.dart`](../../../chapter2/lib/features/x402_approvals/ledger/ledger_ble_client.dart): Bluetooth scan and connect.
- [`eip712_hasher.dart`](../../../chapter2/lib/features/x402_approvals/eip712/eip712_hasher.dart): domain separator and message hash.
- [`x402_approvals_cubit.dart`](../../../chapter2/lib/features/x402_approvals/cubit/x402_approvals_cubit.dart): connect, approver check, approve and reject.
- [`x402_approvals_screen.dart`](../../../chapter2/lib/features/x402_approvals/view/x402_approvals_screen.dart): the Approvals screen.
- [Tests](../../../chapter2/test/features/x402_approvals): EIP-712 vectors, APDU encoding, status words, approval flow.

### Web approval console over WebHID
- Uses Ledger's Device Management Kit and the Ethereum signer kit.
- [`approval-console/src/ledger.ts`](../../../approval-console/src/ledger.ts): connect, read the approver address, and sign typed data or messages.
- [`approval-console/src/signature.ts`](../../../approval-console/src/signature.ts): signature assembly and `EIP712Domain` completion.
- [`approval-console/README.md`](../../../approval-console/README.md)

## 3. The backend only trusts the Ledger

**Approval checks** ([`backend/src/x402/x402-payments.service.ts`](../../../backend/src/x402/x402-payments.service.ts)):
- **`assertValidEscalationTypedData`:** before the human ever sees an escalation, it checks the payer is the Ledger approver, and that the payee, amount, token, chain and expiry match the Guardian's record.
- **`approveWithSignature`:** accepts an approval only if the EIP-712 signature recovers to `LEDGER_APPROVER_ADDRESS` and the authorization hasn't expired.
- **`rejectWithSignature`:** a rejection must also be Ledger-signed.

**Agent waiting for approval** ([`scripts/lib/ledger-remote-signer.ts`](../../../scripts/lib/ledger-remote-signer.ts)): the agent submits the typed data and waits for the Ledger signature. It never holds the approver key.

## End-to-end flow
1. The agent asks the Guardian to pay a service, and the Guardian answers **ESCALATE** (over the autonomous limit).
2. The agent submits the exact USDC authorization, and the backend validates it.
3. The human opens **Approvals** in the app (or the web console), connects the Ledger, and signs on the device.
4. The backend verifies that the signature came from the Ledger approver. The agent completes the x402 payment with it.
5. The facilitator settles on Base Sepolia, and the backend verifies the USDC transfer on-chain.

## Developer experience feedback
[`docs/ledger-dx-feedback.md`](../../ledger-dx-feedback.md) lists 14 concrete items from building this, each with problem, impact and suggested fix. It covers `wallet-cli ring`, DMK over WebHID, and Flutter Bluetooth signing.

## Status
- **Tests:** the Key Ring loading, APDU operations, EIP-712 hashing and approval logic are unit-tested. The backend approval checks have controller tests.
- **Live testing:** live device testing on a Nano X / Flex is in progress with a remote tester.
- **Mobile limitation:** approvals use hashed EIP-712, so the device shows hashes and Blind signing must be enabled. Full clear signing needs an Ethereum signer for Flutter; see DX feedback item 14.

Deeper technical write-up: [`docs/features/x402-ledger-agent-payments.md`](../../features/x402-ledger-agent-payments.md)
