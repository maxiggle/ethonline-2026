# Chapter 2: Development Guide

How to run Chapter 2 locally, configure it, test it with or without a Ledger, and what the security model enforces. For what the project is and how the layers connect, see the [README](../README.md).

## Prerequisites
- Node 20+, Docker (for Postgres), Foundry (`cast`), `jq`
- `wallet-cli` (`npm i -g @ledgerhq/wallet-cli`)
- Chrome or Edge (WebHID)
- A Ledger Nano X or Flex with the Ethereum app
- Base Sepolia USDC from [faucet.circle.com](https://faucet.circle.com) for **both** the agent address and the Ledger address. No ETH is needed, because the facilitator pays gas.

Run all commands from the repo root unless a step says otherwise.

## 1. Provision the Key Ring-protected agent wallet (once)

```bash
security add-generic-password -a default -s ledger-wallet-cli -w
WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) wallet-cli ring init
mkdir -p ~/.chapter2
cast wallet new --json | jq -r '.[0].private_key' | \
  WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) \
  wallet-cli ring encrypt -o ~/.chapter2/agent-key.enc --key chapter2-x402-agent
npm --prefix scripts install
WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) \
AGENT_KEY_SOURCE=ledger-key-ring AGENT_KEY_RING_FILE=~/.chapter2/agent-key.enc AGENT_KEY_RING_KEY_NAME=chapter2-x402-agent \
npm --prefix scripts run agent:address
```

- The first command prompts for the ring password.
- `ring init` needs approval on the device.
- The last command prints the agent address; fund it with USDC.

## 2. Configure and start the backend

```bash
docker compose up -d postgres
cd backend && cp .env.example .env && npm install
npm run start:dev
```

The x402 variables below are required: the backend refuses to start if one is missing. The Privy credentials are needed to bind the agent in step 3.

| Variable | Value / meaning |
|---|---|
| `X402_NETWORK` | `eip155:84532` (Base Sepolia) |
| `X402_FACILITATOR_URL` | `https://x402.org/facilitator` |
| `USDC_ADDRESS` | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| `X402_PAY_TO_ADDRESS` | Seller wallet that receives payments (a fresh address, not the agent or the Ledger) |
| `X402_PARTNER_PAY_TO_ADDRESS` | A second seller address that is **not** approved (used to demo BLOCK) |
| `X402_APPROVED_PAY_TO` | Comma-separated approved payees; includes `X402_PAY_TO_ADDRESS`, excludes the partner address |
| `X402_AUTONOMOUS_LIMIT` | Per-payment autonomous cap in USDC atomic units, e.g. `1000000` ($1.00) |
| `X402_DAILY_LIMIT` | Daily autonomous cap in atomic units, e.g. `5000000` ($5.00) |
| `LEDGER_APPROVER_ADDRESS` | Your Ledger's Ethereum address (`44'/60'/0'/0/0`) |
| `PUBLIC_BASE_URL` | e.g. `http://localhost:3001` |
| `PRIVY_APP_ID`, `PRIVY_APP_SECRET` | Privy app credentials. Without them every bearer token is rejected, so the agent can't be bound |

## 3. Bind the agent to your Chapter 2 user

The payments API only accepts requests signed by an `ACTIVE` bound agent. Bind yours in the mobile app (onboarding step 2, or **Bind your agent** on Home), or call the API with your Privy bearer token:

```bash
curl -X POST http://localhost:3001/agents/bind \
  -H "Authorization: Bearer $PRIVY_TOKEN" -H 'Content-Type: application/json' \
  -d '{"agentAddress":"<agent address>","name":"x402 agent","safeAddress":"0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6","guardAddress":"0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3","chainId":84532}'
```

Binding an address that was bound before reactivates that agent. Binding an address that another account has active returns `409`.

## 4. Approve escalations on the Ledger

- **Mobile app:** open the **Approvals** tab, connect the Nano X / Flex over Bluetooth, and approve or reject. The Ethereum app's **Blind signing** setting must be on, because the device shows the EIP-712 hashes.
- **Web console:**

  ```bash
  cd approval-console && cp .env.example .env && npm install
  npm run dev
  ```

  Open it in Chrome or Edge and click **Connect Ledger**. Keep the device unlocked with the Ethereum app open. The console checks that the device address matches `LEDGER_APPROVER_ADDRESS`.

## 5. Run the agent

### Scripted demo
```bash
WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) \
AGENT_KEY_SOURCE=ledger-key-ring AGENT_KEY_RING_FILE=~/.chapter2/agent-key.enc \
AGENT_KEY_RING_KEY_NAME=chapter2-x402-agent \
API_BASE_URL=http://localhost:3001 \
npm --prefix scripts run demo:x402
```

Pass `-- --scenario=allow|escalate|block` to run a single scenario:
- **allow:** `$0.01` weather, paid by the agent wallet.
- **escalate:** `$2.00` chain report. Approve it on your Ledger within 15 minutes.
- **block:** a partner feed with an unapproved payee; no signature is made.

Demo video plan and pre-submission checklist: [demo-script.md](demo-script.md).

### Buy services from the app (agent worker)
- **In the app:** the **Services** tab lists the backend's x402 catalog (`GET /discovery/resources`). **Ask agent to pay** creates a purchase request.
- **The worker:** claims and pays these requests:

  ```bash
  WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) \
  AGENT_KEY_SOURCE=ledger-key-ring AGENT_KEY_RING_FILE=~/.chapter2/agent-key.enc \
  AGENT_KEY_RING_KEY_NAME=chapter2-x402-agent \
  API_BASE_URL=https://chapter2-backend.onrender.com \
  npm --prefix scripts run agent:worker
  ```

- **How it runs:**
  - Polls `POST /x402/purchase-requests/claim` every 5 seconds.
  - Pays the oldest queued request through the Guardian-gated flow (ALLOW / ESCALATE / BLOCK).
  - Reports the Guardian's decision as soon as it authorizes the payment, then reports `PAID`, `BLOCKED`, `REJECTED`, `EXPIRED` or `FAILED`.
  - `Ctrl-C` finishes the request in flight before exiting.

Without the app, you can create a request directly:

```bash
curl -X POST https://chapter2-backend.onrender.com/x402/purchase-requests \
  -H "Authorization: Bearer $PRIVY_TOKEN" -H 'Content-Type: application/json' \
  -d '{"agentAddress":"<agent address>","resourceUrl":"https://chapter2-backend.onrender.com/x402/weather","queryParams":{"city":"Lagos"},"justification":"Brief the morning report."}'
```

`resourceUrl` must be a `resource` from the same backend's `GET /discovery/resources`. The worker only pays resources on its own `API_BASE_URL`.

## Test the payment rail without a Ledger

`ring init` needs the Ledger plugged in. To test a real x402 payment on a machine without the device, load a test agent key from a password-encrypted Foundry keystore instead.
- This only replaces how the agent's key is loaded.
- Escalated payments still need the Ledger approver.
- The demo itself uses `AGENT_KEY_SOURCE=ledger-key-ring`.

```bash
mkdir -p ~/.foundry/keystores
security add-generic-password -a default -s chapter2-test-agent -w
cast wallet new ~/.foundry/keystores chapter2-test-agent
```

The Keychain command must end with `-w` so it prompts for the password. `cast wallet new` asks for that same password and prints the test agent's address. Fund that address with Base Sepolia USDC and bind it as in step 3.

```bash
AGENT_KEY_SOURCE=foundry-keystore \
AGENT_KEYSTORE_FILE=~/.foundry/keystores/chapter2-test-agent \
AGENT_KEYSTORE_PASSWORD=$(security find-generic-password -a default -s chapter2-test-agent -w) \
API_BASE_URL=https://chapter2-backend.onrender.com \
npm --prefix scripts run agent:worker
```

`AGENT_KEY_SOURCE` has no default; the agent refuses to start without it.

## Security model and known limitations

- **What's enforced:**
  - Agent requests are authenticated by an EIP-191 signature from the agent's key, with a timestamp and a single-use signature.
  - The spending policy (network, USDC asset, approved payee, per-payment and daily limits) runs before any payment signature exists.
  - Escalation typed data is checked against the Guardian's record (payer = Ledger, payee, amount, token, chain, expiry). The approval must recover to the Ledger address.
  - Settlement is confirmed by reading the USDC `Transfer` log on-chain. A purchase request is marked `PAID` only when the backend has verified that settlement.
- **Human verification with World ID is designed but not enforced yet.** Escalated approvals currently require only the Ledger signature. The World ID Selfie Check verification service is built and tested, but World hasn't approved Selfie Check for this app, and enforcing it now would block every approval. See [world-id-approval-gate.md](world-id-approval-gate.md).
- **The backend holds no signing keys.** `OnChainExecutorService` only reads Base Sepolia (settlement verification, contract state, balances), so the legacy Safe / `Chapter2Guard` execution path is disabled: `/actions` approvals are recorded but never broadcast. The Guard's former owner / `humanSigner` key was exposed; it stays in git history and must never hold funds.
- **Agent binding doesn't prove key control yet.** Anyone signed in can bind an address. A signed binding challenge is planned.
- **Single-instance state:**
  - The agent-signature replay cache, purchase-request claim locks and escalation reasons awaiting typed data are held per backend instance.
  - Settlement verification has no cross-action replay guard.
- **Mobile Ledger approvals** use the v0 hashed EIP-712 command, so the device shows hashes and Blind signing must be on. The app never holds the agent's key.
- **`native_security/`** holds iOS/Android biometric plugin prototypes. The app doesn't use them, and they aren't production security controls.
- **Without a Ledger origin token** (`VITE_LEDGER_ORIGIN_TOKEN`), the web console still signs, with reduced Ledger-side transaction checks.

## Monorepo structure

- `chapter2/`: Flutter mobile app. Privy login, onboarding, Services, Ledger Bluetooth approvals, activity.
- `backend/`: NestJS API. Guardian spending policy, x402 v2 seller endpoints and Bazaar discovery, Guardian-gated payments, purchase requests, World ID verification.
- `scripts/`: the agent worker and demo client (Key Ring or Foundry keystore key + x402 client).
- `approval-console/`: Ledger DMK / WebHID web console for escalated payments.
- `contracts/`: Foundry contracts (`Chapter2Guard` Safe transaction guard), used by the legacy execution path.
- `native_security/`: native biometric plugin prototypes (not used).
- `docs/`: partner pages, feature docs, tickets.
