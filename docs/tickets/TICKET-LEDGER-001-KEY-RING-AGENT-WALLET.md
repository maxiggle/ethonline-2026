# TICKET LEDGER-001: Ledger Key Ring-Protected Agent Wallet

**Lane:** A · **Time box:** 45 min · **Component:** `scripts/`, ops · **Read first:** `docs/tickets/README.md`

## Why
The ETHOnline 2026 Ledger prize requires building on the Ledger Agent Stack, **in particular `wallet-cli ring`** (Ledger Key Ring). The autonomous agent's x402 payment key must never sit in plaintext. It is encrypted under a key ring tied to the user's Ledger and decrypted in memory only when the agent starts.

The legacy backend "LKRP" (`backend/src/ledger/ledger-keyring.service.ts`) is an in-process AES imitation. Do **not** use or extend it for this.

## 👤 Human steps (user runs these; the agent must not handle keys)
1. **Prepare the device:** plug in the Nano X or Flex over **USB**, unlock it, and open/install the **Ethereum** app. Update firmware if Ledger Wallet asks.
2. **Install the CLI:** `npm i -g @ledgerhq/wallet-cli`, then check with `wallet-cli --help`.
3. **Store the ring password in Keychain:** `security add-generic-password -a default -s ledger-wallet-cli -w` (it prompts for the password).
4. **Provision the ring** (approve on the device):
   ```bash
   WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) wallet-cli ring init
   ```
5. **Create the agent key and encrypt it straight into the ring, never writing plaintext to disk:**
   ```bash
   mkdir -p ~/.chapter2
   cast wallet new --json | jq -r '.[0].private_key' | \
     WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) \
     wallet-cli ring encrypt -o ~/.chapter2/agent-key.enc --key chapter2-x402-agent
   ```
   If `cast wallet new --json` has a different shape on your Foundry version, adjust the `jq` path. Confirm with `wallet-cli ring keys`.
6. **Get the agent address:** run `npm --prefix scripts run agent:address` (built below).
7. **Fund the agent address** with Base Sepolia **USDC** from https://faucet.circle.com. No ETH is needed, because the x402 facilitator pays gas.
8. **Fund the Ledger address** (`44'/60'/0'/0/0`) with Base Sepolia USDC too, since escalated payments are paid from it. Get the address from Ledger Wallet or the LEDGER-002 console.
9. **Bind the agent** to your Chapter 2 user as an ACTIVE agent. Use the mobile app's "Add Agent" sheet, or `POST /agents/bind` with your Privy bearer token.

## Implementation
1. **`scripts/package.json`** (new; the scripts folder becomes its own package):
   - Dependencies, pinned exactly: `viem`, `@x402/fetch`, `@x402/core`, `@x402/evm`.
   - Dev dependencies: `tsx`, `typescript`, `@types/node`.
   - Scripts: `"agent:address": "tsx agent-address.ts"`, `"demo:x402": "tsx agent-x402-client.ts"`, `"typecheck": "tsc --noEmit"`.
   - Add a `scripts/tsconfig.json` suited for ESM + Node 20.
2. **`scripts/lib/ledger-key-ring.ts`:**
   ```ts
   export async function decryptWithLedgerKeyRing(options: { inputFile: string; keyName: string }): Promise<string>
   ```
   - Require `WALLET_PASS` in `process.env` and throw a clear error when it's missing.
   - Spawn `wallet-cli ring decrypt -i <inputFile> --key <keyName>` with `shell: false`, pass the env through, and capture stdout. Confirm the exact flags against `wallet-cli ring decrypt --help` and adjust.
   - Trim the output and validate `/^0x[0-9a-fA-F]{64}$/` (add the `0x` prefix if the stored key lacks it).
   - Map failures to clear errors: CLI not installed (ENOENT), non-zero exit (include stderr **without** echoing the secret), invalid output.
   - Never log, cache to disk, or include the key in thrown messages.
3. **`scripts/lib/agent-account.ts`:** `loadAgentAccount()` reads the required env `AGENT_KEY_RING_FILE` / `AGENT_KEY_RING_KEY_NAME`, calls `decryptWithLedgerKeyRing`, and returns a viem `privateKeyToAccount` account.
4. **`scripts/agent-address.ts`:** prints only the agent address.
5. **`.gitignore`:** add `scripts/node_modules/` and `*.enc`.
6. **Tests:** add `scripts/lib/ledger-key-ring.test.ts` using `node:test` or vitest. Mock `child_process.spawn` and cover success, missing `WALLET_PASS`, ENOENT, non-zero exit, and malformed output. Assert thrown messages never contain the mocked key.

## Acceptance criteria
- **Address printed:** `WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) AGENT_KEY_RING_FILE=~/.chapter2/agent-key.enc AGENT_KEY_RING_KEY_NAME=chapter2-x402-agent npm --prefix scripts run agent:address` prints the funded agent address.
- **No plaintext anywhere:** no plaintext key exists in the repo, on disk, or in logs.
- **Checks pass:** `npm --prefix scripts run typecheck` and the unit tests.
- **Commits:** `feat(client): decrypt the x402 agent key with the Ledger Key Ring`.
