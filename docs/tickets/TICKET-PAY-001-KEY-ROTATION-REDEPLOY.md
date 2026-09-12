# TICKET PAY-001: Rotate Leaked Keys & Redeploy Chapter2Guard / Safe

**Component:** `contracts/`, `backend/`, ops · **Priority:** Critical / blocking · **Read first:** `docs/tickets/README.md`

> **Human-owned steps are marked 👤.** An agent must not generate, handle or paste private keys, fund wallets, move funds, or broadcast deployments on its own. It prepares the code and config, then hands those steps to the user.

## Problem
1. **The key is public.** The relayer private key (address `0x988B225185b516DEF12A7Ec841abae9072ef4EE8`) was committed to the public GitHub repo in commit `03e4dbb`. That address is:
   - the MockSafe `owner`
   - the Chapter2Guard `owner`
   - the Chapter2Guard `humanSigner`
2. **Nobody can change the owner.** Chapter2Guard has no ownership transfer, so rotating keys means redeploying.
3. **The owner bypasses every check.** `Chapter2Guard.checkTransaction` returns early when `msgSender == owner`. The backend relayer (the owner) sends every Safe transaction, so caps, whitelists and signature checks are never enforced.
4. **The agent that sends and the agent the Guard expects are different.** The Guard's autonomous path requires `msgSender == autonomousAgent`, but the backend sends transactions from the relayer. Meanwhile `AgentsService.bindAgent` calls `setAutonomousAgent(<user's Privy wallet>)`, which is one global slot that every user overwrites.

## Decision required (👤 user) before coding
Choose the execution identity model and record it in the ticket PR:
- **Option A (recommended for the demo):** the backend relayer key **is** the on-chain `autonomousAgent`, while `owner` and `humanSigner` are separate keys that the backend never holds. Per-user agents stay backend records that authorize proposals, and nothing changes on-chain per user. Remove the `setAutonomousAgent` call from `AgentsService.bindAgent`.
- **Option B:** each user's Privy wallet submits its own Safe transactions from the mobile app, and the relayer only reads chain state. This needs one Guard (or mandate) per user, which is much larger.

## Implementation (Option A)
1. **`contracts/script/DeployChapter2.s.sol`:**
   - Read `OWNER_ADDRESS`, `HUMAN_SIGNER_ADDRESS`, `AUTONOMOUS_AGENT_ADDRESS`, `TREASURY_TOKEN_ADDRESS` and `APPROVED_RECIPIENTS` from env.
   - Require that owner, humanSigner and autonomousAgent are **three distinct addresses**, and revert otherwise.
   - Call `setApprovedToken(TREASURY_TOKEN_ADDRESS, true)` and `setApprovedRecipient` for each recipient.
   - Note that the Safe owner must not be the relayer either.
   - Add a Foundry test asserting the script's invariants, where practical.
2. **Contracts, owner bypass:** decide whether an owner-sent tx should still skip the Guard. At minimum, add a test proving that a tx sent by the `autonomousAgent` above the cap reverts without a valid `humanSigner` signature. Gate: `forge test -vvv`.
3. **Backend:**
   - Remove `onChainExecutor.setAutonomousAgent` from `AgentsService.bindAgent` (`backend/src/agents/agents.service.ts`).
   - On startup, `OnChainExecutorService` should read `autonomousAgent()`, `humanSigner()` and `owner()` from the Guard. It should **throw** if the relayer address ≠ `autonomousAgent`, or if the relayer equals `owner` or `humanSigner`.
4. **Config:** update `backend/.env.example` (add `VENDOR_RECIPIENT_ADDRESS`, `USDC_ADDRESS`, `WORLD_ID_MODE`, `LEDGER_MODE`), `render.yaml` (new addresses; secrets stay `sync: false`), and `contracts/deployments/base-sepolia.json` after 👤 deployment.
5. **Spec cleanup:** `backend/src/blockchain/on-chain-executor.service.spec.ts` asserts the relayer is `0x988B…`. Make it read the expected address from env.

## 👤 Human steps
1. Move any funds out of the old Safe `0x4f71…1df6` using the old key.
2. Generate new keys for owner, humanSigner (ideally a Ledger) and relayer/autonomousAgent. Fund the relayer with Base Sepolia ETH.
3. Run the deploy script and verify the contracts on Blockscout.
4. Update Render secrets and the local `.env`.
5. Optional: scrub the leaked key from git history (`git filter-repo`, then force-push). Rotation is required either way.

## Acceptance criteria
- **Distinct roles:** the new Guard has distinct `owner`, `humanSigner` and `autonomousAgent`, none of them the leaked address.
- **Enforced checks:** a relayed autonomous transfer above `maxAutonomousAmount` reverts on-chain.
- **Startup check:** the backend refuses to start when the on-chain roles don't match its relayer.
