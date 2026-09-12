# Ledger Approval Console

A single-page console that lets the human approver review and sign
**escalated** x402 payments on their Ledger hardware wallet (Nano X or Flex)
over WebHID, using Ledger's Device Management Kit (DMK) and Ethereum signer
kit. It talks to the backend's public `/x402/approvals/*` endpoints
(see `TICKET-X402-002-GUARDIAN-GATED-PAYMENTS-API.md`); the authority for
every state change is the Ledger's own signature, verified server-side.

## Setup

```bash
cd approval-console
npm install
cp .env.example .env
```

## Environment

| Variable | Required | Meaning |
|---|---|---|
| `VITE_API_BASE_URL` | yes | Backend base URL, e.g. `http://localhost:3001` |
| `VITE_LEDGER_ORIGIN_TOKEN` | no | Ledger partner origin token, if you have one. When absent the console shows a banner and still works, with reduced Ledger-side transaction checks. Never invent a value. |

## Run

```bash
npm run dev
```

Open the printed URL in **Chrome or Edge** — WebHID requires one of those
browsers, plus `localhost` or HTTPS, plus a user gesture to open the device
picker (the **Connect Ledger** button).

## Device prerequisites

- Nano X or Flex, connected over USB, unlocked, with the **Ethereum** app open.
- **Blind signing**: the USDC `TransferWithAuthorization` payload used by the
  x402 escalation flow is clear-signed on current Ethereum-app firmware
  (the device shows amount, recipient and expiry as named fields). If your
  device's Ethereum app version instead shows a blind-signing warning for
  this message, enable **Blind signing** in the Ethereum app's settings
  before approving. This was flagged as DX feedback in
  `TICKET-SUBMIT-001-DOCS-AND-DEMO.md`.

## Flow

1. **Connect Ledger** discovers and connects a device via DMK/WebHID, opens
   an Ethereum signer for `44'/60'/0'/0/0`, and reads that path's address.
2. The console fetches `GET /x402/approvals/config`. If the device address
   doesn't match the configured `approverAddress`, approvals are disabled
   with a blocking banner — the backend would reject the signature anyway,
   but the UI catches it first.
3. **Pending list** polls `GET /x402/approvals/pending` every 3 seconds and
   renders each escalation: resource, USDC amount, payTo, agent, Guardian
   risk score and reasons, and the authorization expiry.
4. **Approve** completes the typed data's `EIP712Domain` type if the backend
   omitted it, asks the signer to `signTypedData`, assembles the 65-byte
   `r ‖ s ‖ v` signature, and posts it to
   `POST /x402/approvals/:actionId/signature`.
5. **Reject** signs `chapter2-reject:<actionId>` with `personal_sign` and
   posts it to `POST /x402/approvals/:actionId/reject`.

## Testing

```bash
npm run typecheck
npm test
```

`npm test` runs vitest unit tests for the pure signature-assembly and
`EIP712Domain`-completion logic (`src/signature.test.ts`). The Ledger
connect/approve/reject flow itself needs a real device and is verified
manually against a running backend.
