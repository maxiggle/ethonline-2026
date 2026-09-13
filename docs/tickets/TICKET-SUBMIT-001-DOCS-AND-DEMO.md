# TICKET SUBMIT-001: Submission Docs, Ledger DX Feedback & Demo

**Time box:** 45 min · **Component:** `README.md`, `docs/` · **Depends on:** all submission-track tickets · **Read first:** `docs/tickets/README.md`

## Why
The Ledger prize requires:
- a public repo with working code;
- a demo video;
- **clear documentation of how Ledger enables the solution.**

DX feedback is judged as much as the code.

## Implementation
1. **Root `README.md`** (rewrite the top; keep it scannable):
   - **What Chapter 2 is:** an AI Guardian for agent treasuries, in one paragraph.
   - **Architecture:** a Mermaid diagram of the flow: agent → x402 resource `402` → Guardian (`/x402/payments/authorize`) → then one of:
     - ALLOW: Key Ring-decrypted agent wallet signs EIP-3009;
     - ESCALATE: Ledger web console signs EIP-3009 on-device;
     - BLOCK: no signature.

     After a signature: x402.org facilitator settles on Base Sepolia → backend verifies the `Transfer` log.
   - **How Ledger is used** (explicit, for judges):
     1. `wallet-cli ring` protects the agent's payment key. It's decrypted in memory only; the device is required to provision the ring.
     2. Human-in-the-loop: escalated payments are signed on a Nano X / Flex through DMK over WebHID.
     3. Backend approvals only accept signatures recovering to the Ledger approver address.
   - **Run the demo locally:** prerequisites (Node 20, Docker Postgres, Foundry `cast`, `wallet-cli`, a Chrome browser, a Ledger with the Ethereum app, and Base Sepolia USDC from the Circle faucet), the full env table (copy it from `docs/tickets/README.md`), and the commands in order:
     1. backend
     2. approval console
     3. `npm --prefix scripts run demo:x402`
   - **Security model and known limitations** (be honest):
     - The legacy Safe/Chapter2Guard execution path and `/vendor/*` rail aren't used by the x402 demo.
     - The deployed Guard's owner and humanSigner are a development wallet and must be replaced by a redeploy (PAY-001).
     - Replay protection for the legacy rail is single-instance.
     - The Flutter app shows x402 actions in its timeline but doesn't yet sign.
2. **`docs/features/x402-ledger-agent-payments.md`** (repo feature-doc format: Overview, How It Was Built, Data Flow & Interfaces, Trade-offs / Edge Cases). Cover the API contract from X402-002, the agent request signature scheme, the spending policy, and the escalation typed-data checks.
3. **`docs/ledger-dx-feedback.md`:** gather concrete friction from the implementers of LEDGER-001, LEDGER-002 and X402-003. For each item, give the problem, the impact, and a suggested fix. For example:
   - the `wallet-cli ring` password/env handling;
   - `ring decrypt` flags and output behaviour;
   - DMK builder/transport API changes versus the docs;
   - the `originToken` requirement;
   - WebHID browser limits;
   - clear signing vs a blind-signing warning for USDC `TransferWithAuthorization` on Nano X vs Flex;
   - error messages.

   Only real observations; don't invent any.
4. **`docs/demo-script.md`:** a video plan under 4 minutes, split into scenes:
   1. problem (10 s);
   2. architecture diagram (20 s);
   3. `ring` protecting the agent key (show `wallet-cli ring keys`, never the key);
   4. ALLOW payment with the Blockscout tx;
   5. ESCALATE: approve on the Ledger Flex screen, show the Blockscout tx from the Ledger address;
   6. BLOCK;
   7. timeline in the backend/mobile app;
   8. closing.
5. **👤 Human pre-submission checklist** (put it in `docs/demo-script.md`):
   - The old development wallet `0x988B…` holds no funds, and Render secrets are rotated.
   - `git grep -nIE "PRIVATE_KEY *= *['\"]?0x[0-9a-fA-F]{64}"` returns nothing in the current tree.
   - The demo runs end-to-end twice in a row.
   - The branch is merged/pushed per your git workflow, and the repo is public.

## Acceptance criteria
- **Understandable in 3 minutes:** a judge can understand what Ledger does in the product from the README alone.
- **Reproducible:** the demo steps work on a clean clone with the documented env.
- **Commits:** docs-only commits, e.g. `docs(repo): document x402 and Ledger agent payment demo` and `docs(features): add x402 Ledger agent payments feature doc`.
