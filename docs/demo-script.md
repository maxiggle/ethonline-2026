# Chapter 2 Demo Video Script (under 4 minutes)

The demo shows an autonomous agent paying for real x402 v2 resources on Base Sepolia. The Chapter 2 Guardian decides **ALLOW / ESCALATE / BLOCK** before any signature exists. The Ledger protects both sides: the agent's key is locked in `wallet-cli ring`, and escalated payments are signed on the device.

## Before recording

Have these open and ready:

| Window | State |
|---|---|
| Terminal 1 | Backend running (`cd backend && npm run start:dev`), logs visible |
| Chrome | Approval console (`cd approval-console && npm run dev`), Ledger connected, address matches the approver banner |
| Terminal 2 | In repo root, `WALLET_PASS` **not** exported in shell history (use the inline `$(security …)` form) |
| Ledger Flex / Nano X | Unlocked, Ethereum app open, in camera view |
| Browser tab | `https://base-sepolia.blockscout.com` |

Do a full dry run first; every settlement costs real testnet USDC from the agent and the Ledger address.

## Scenes

### 1. Problem (0:00–0:10)
**Show:** title card.
**Say:** "AI agents can now pay for APIs on their own with x402. The question isn't whether they can pay, it's who decides whether they should, and where the keys live."

### 2. Architecture (0:10–0:30)
**Show:** the Mermaid diagram from the root `README.md`.
**Say:** "Every payment request goes to the Chapter 2 Guardian before anything is signed. Small, approved payments are signed by the agent's wallet, whose key is encrypted by the Ledger Key Ring. Payments over the limit are signed on my Ledger. Unapproved payees are blocked outright. Settlement goes through the public x402 facilitator, and the backend verifies the USDC transfer on-chain."

### 3. Ledger Key Ring protects the agent key (0:30–0:55)
**Run:**
```bash
wallet-cli ring keys
```
**Show:** the `chapter2-x402-agent` key listed, and `~/.chapter2/agent-key.enc` being ciphertext (`head -c 64 ~/.chapter2/agent-key.enc | xxd`). **Never** show a decrypted key.
**Say:** "The agent's private key only exists encrypted under a key ring provisioned with my Ledger. The agent decrypts it in memory at startup; it is never on disk in plaintext."

### 4. ALLOW: autonomous payment (0:55–1:35)
**Run:**
```bash
WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) \
AGENT_KEY_SOURCE=ledger-key-ring AGENT_KEY_RING_FILE=~/.chapter2/agent-key.enc \
AGENT_KEY_RING_KEY_NAME=chapter2-x402-agent \
API_BASE_URL=http://localhost:3001 \
npm --prefix scripts run demo:x402 -- --scenario=allow
```
**Show:** the 402 challenge, the `$0.01` price, Guardian decision `ALLOW`, the settlement hash, the real Lagos weather, then click the Blockscout link: the USDC transfer is **from the agent address**.
**Say:** "One cent, approved payee, under the limit: the Guardian allows it and the agent pays by itself."

### 5. ESCALATE: human approves on the Ledger (1:35–2:40)
**Run:** the same command with `--scenario=escalate`.
**Show:**
1. Terminal: `$2.00` chain report, Guardian decision `ESCALATE` with the policy reason (over the autonomous limit), "Waiting for approval on Ledger console…".
2. Console: the pending card with resource, amount, payee, risk score, reasons and expiry.
3. Click **Approve**; film the Ledger screen showing the `TransferWithAuthorization` fields; confirm on the device.
4. Terminal: settlement hash and real chain data. Blockscout: the transfer is **from the Ledger address**.

**Say:** "Two dollars is over what I let the agent spend alone. Nothing gets signed until I approve it on my Ledger. The backend only accepts a signature that recovers to my Ledger address."

### 6. BLOCK (2:40–3:05)
**Run:** the same command with `--scenario=block`.
**Show:** Guardian decision `BLOCK`, the reason (payee not on the approved list), and that no signature or transaction was produced.
**Say:** "An unapproved payee is never paid, not even with human approval: no signature is ever created."

### 7. Timeline (3:05–3:30)
**Show:** the backend logs or the mobile app activity timeline listing the three `TreasuryAction`s: `EXECUTED` (allow), `EXECUTED` (escalate), `REJECTED` (block).
**Say:** "Every decision is recorded as a treasury action, whichever path it took."

### 8. Closing (3:30–3:50)
**Say:** "Chapter 2: agents move fast, the Guardian decides, and the Ledger holds the keys to everything that matters."

## 👤 Human pre-submission checklist

- [ ] The leaked relayer `0x988B225185b516DEF12A7Ec841abae9072ef4EE8` holds no funds, and Render secrets are rotated (PAY-001).
- [ ] `git grep -nIE "PRIVATE_KEY *= *['\"]?0x[0-9a-fA-F]{64}"` returns nothing in the current tree.
- [ ] The demo runs end-to-end twice in a row (`--scenario=all`), with fresh USDC balances on both the agent and the Ledger address.
- [ ] The branch is merged/pushed per your git workflow, and the repo is public.
- [ ] The video is uploaded and linked in the submission form.
