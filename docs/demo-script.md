# Chapter 2 Demo Video Script (under 4 minutes)

The story: a company's AI agent buys services on its own, and the **Guardian** decides every payment:
- a small one is paid by the agent;
- a big one waits for a human's **Ledger**;
- an unapproved one is blocked.

The agent's key is protected by the **Ledger Key Ring**.

## Before recording

| Window | State |
|---|---|
| **Phone** | Chapter 2 app, signed in, agent bound and **ACTIVE**, screen recording on |
| **Terminal** | Agent worker running with `AGENT_KEY_SOURCE=ledger-key-ring` (see [development.md](development.md)), text large enough to read |
| **Ledger Nano X / Flex** | Unlocked, Ethereum app open, **Blind signing** on, in camera view |
| **Browser tab** | `https://base-sepolia.blockscout.com` |

**Setup checks:**
- The Render backend is live, and `LEDGER_APPROVER_ADDRESS` is the Ledger in the video.
- The agent and the Ledger address both hold Base Sepolia USDC.
- `ring init` and the agent key setup were done on the machine that runs the worker, with the Ledger connected.
- Do a full dry run first. Every paid step moves real testnet USDC.

## Scenes

### 1. Problem (0:00–0:15)
**Show:** title card.
**Say:** "AI agents can now pay for APIs by themselves. For a company, the question isn't whether an agent can pay, it's who decides whether it should, and who holds the keys."

### 2. How it works (0:15–0:35)
**Show:** the layer diagram from the [README](../README.md).
**Say:** "Chapter 2 has two layers. The agent layer is an AI agent whose wallet key is locked by the Ledger Key Ring. The management layer is our app and the Guardian: every payment is checked before it's signed. Small ones are allowed, big ones go to my Ledger, unapproved ones are blocked."

### 3. The agent's key is protected by Ledger (0:35–0:55)
**Show:** the terminal with `wallet-cli ring keys` listing `chapter2-x402-agent`, then the worker starting and printing the agent address with `key source: ledger-key-ring`. **Never** show a decrypted key.
**Say:** "The agent's private key only exists encrypted under a Key Ring set up with my Ledger. The agent decrypts it in memory when it starts. It's never on disk and never sent to our servers."

### 4. Browse services and buy one: ALLOW (0:55–1:40)
**Show:**
1. App **Services** tab: the catalog; type "weather" to filter it.
2. Open **Open-Meteo Weather Oracle** ($0.01), set a city, and tap **Ask agent to pay**.
3. Purchase detail moves through Queued, Processing, Authorized, **Paid**, while the worker terminal logs each step.
4. The weather data appears in the app. Copy the transaction link, open it in Blockscout, and show the USDC transfer **from the agent address**.

**Say:** "One cent to an approved service, under the agent's limit. The Guardian allows it and the agent pays by itself, with real USDC, verified on-chain."

### 5. A big purchase needs my Ledger: ESCALATE (1:40–2:45)
**Show:**
1. Services: **Base Sepolia Chain Report** ($2.00), then **Ask agent to pay**.
2. Purchase detail shows **Needs your Ledger approval** with the Guardian's reason. Tap **Open Approvals**.
3. Approvals tab: **Connect Ledger** over Bluetooth, and the address matches the approver. Tap **Approve**.
4. Film the Ledger screen and confirm on the device.
5. Back in the purchase detail: **Paid**. Blockscout shows the transfer **from the Ledger address**.

**Say:** "Two dollars is over what I let the agent spend alone. Nothing moves until I approve it on my Ledger, and our backend only accepts a signature from that exact device."

### 6. An unapproved service is blocked: BLOCK (2:45–3:10)
**Show:** Services: **Partner Chain Feed**, then **Ask agent to pay**. The purchase ends **Blocked**, with the reason "payee not on the approved list". The worker logs BLOCKED.
**Say:** "An unapproved payee is never paid. No signature is ever created."

### 7. Everything is on record (3:10–3:30)
**Show:** the Activity tab with the three actions: allowed, escalated then executed, blocked.
**Say:** "Every decision the Guardian made is recorded, whichever path it took."

### 8. Closing (3:30–3:50)
**Say:** "Chapter 2: agents move fast, the Guardian decides, and the Ledger holds the keys to everything that matters."

## Pre-submission checklist

- [ ] **Old development wallet:** funds moved off `0x988B…4EE8` and out of the retired MockSafe `0x4f71…1df6`.
- [ ] **Render environment:** `RELAYER_PRIVATE_KEY` and `DEPLOYER_PRIVATE_KEY` are deleted.
- [ ] **No committed keys:** `git grep -nIE "PRIVATE_KEY *= *['\"]?0x[0-9a-fA-F]{64}"` finds nothing in the current tree.
- [ ] **Demo rehearsal:** scenes 4–6 run end-to-end twice in a row with the Ledger-backed agent.
- [ ] **Partner links submitted:**
  - [docs/partners/ledger](partners/ledger)
  - [docs/partners/privy](partners/privy)
  - [docs/partners/world](partners/world)
- [ ] **Video:** uploaded and linked in the submission form.
- [x] **Repository:** public.
