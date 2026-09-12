# TICKET LEDGER-002: Ledger Web Approval Console (DMK over WebHID)

**Lane:** C · **Time box:** 2 h · **Component:** new `approval-console/` · **Depends on:** X402-002 API contract · **Read first:** `docs/tickets/README.md`

## Why
Escalated x402 payments must be approved **on the human's Ledger device** (Nano X or Flex over USB). Ledger's TypeScript Device Management Kit (DMK) with WebHID is the mature path for EIP-712 signing. The console signs the USDC EIP-3009 `TransferWithAuthorization` itself, so the escalated payment is literally paid from the Ledger account.

## Implementation
1. **Scaffold:** `approval-console/` with Vite + TypeScript. Plain TS or minimal React, whichever is faster; keep it one page.
   - Dependencies, pinned exactly: `@ledgerhq/device-management-kit`, `@ledgerhq/device-signer-kit-ethereum` (plus peer deps such as `rxjs`), `viem` for hex helpers.
   - Read the current docs before coding, because the APIs changed between versions:
     - https://developers.ledger.com/docs/device-interaction/dmk-ts
     - https://developers.ledger.com/docs/device-interaction/dmk-ts/references/signers/eth
     - the packages' READMEs and types in `node_modules`

     Use the builder / transport-factory API they document. It may differ from older samples such as `new DeviceManagementKit({ transport: new WebHidTransport() })`.
2. **Env:** `VITE_API_BASE_URL` is required. `VITE_LEDGER_ORIGIN_TOKEN` is optional: if it's absent, show a banner "Ledger transaction checks unavailable (no origin token)". Never invent a token.
3. **Connect flow** (WebHID needs a user gesture and Chrome/Edge on `localhost` or HTTPS):
   1. Click **Connect Ledger** to discover and connect with DMK.
   2. Show the connection state, with guidance: unlock the device and open the Ethereum app.
   3. Build the Ethereum signer (pass `originToken` when set) and call `getAddress("44'/60'/0'/0/0", { checkOnDevice: false })`.
   4. Fetch `GET /x402/approvals/config`. If the device address ≠ `approverAddress`, show a blocking error ("This Ledger is not the configured approver") and disable approvals.
4. **Pending list:**
   - Poll `GET /x402/approvals/pending` every 3 s.
   - Each card shows the resource URL, amount formatted as USDC (6 decimals), payTo, agent address, justification, risk score, Guardian reasons, and the authorization expiry (`validBefore`).
5. **Approve:**
   1. Take `typedData` from the card. If `types.EIP712Domain` is missing, add it from the domain fields present (`name`, `version`, `chainId`, `verifyingContract`). Serialize bigint values as decimal strings or numbers, as the signer expects.
   2. Call `signerEth.signTypedData("44'/60'/0'/0/0", typedData)` and subscribe to the observable. Show "Review and confirm on your Ledger" while user interaction is pending.
   3. On completion, assemble the 65-byte signature `0x || r(32) || s(32) || v`. Normalize r/s hex with no `0x`, left-padded to 64 chars, and v to 27/28.
   4. `POST /x402/approvals/:actionId/signature` with `{ signature }`.
   5. Show success, or the backend error.
6. **Reject:** `signerEth.signMessage("44'/60'/0'/0/0", "chapter2-reject:<actionId>")`, assemble the signature the same way, then `POST /x402/approvals/:actionId/reject`.
7. **Error handling:** map DMK errors to readable messages: device locked, wrong app, user rejected on device, WebHID not supported, disconnected. Never swallow errors.
8. **Clear signing:** record what the Nano X and Flex actually display for USDC `TransferWithAuthorization` (clear-signed fields vs a blind-signing warning). If the Ethereum app requires **Blind signing** enabled, document it in `approval-console/README.md` and add it to the DX feedback (SUBMIT-001).
9. **Tests:** vitest unit tests for the signature assembly (r/s/v normalization) and the EIP712Domain completion. `npx tsc --noEmit` passes.
10. **`approval-console/README.md`:** setup, env, supported browsers, device prerequisites, run command (`npm run dev`).

## Acceptance criteria
- **Real device approval:** with a Nano X or Flex over USB, an escalated payment created by X402-003 appears in the console, is confirmed on the device, and the backend accepts the signature (escalation `SIGNED`, action `APPROVED`).
- **Wrong device blocked:** a non-approver Ledger can't approve (blocked in the UI; the backend would reject it anyway).
- **Reject works:** it produces a Ledger-signed rejection.
- **Commits** (for example):
  - `feat(console): connect Ledger over WebHID and verify approver address`
  - `feat(console): approve and reject escalated x402 payments on Ledger`
