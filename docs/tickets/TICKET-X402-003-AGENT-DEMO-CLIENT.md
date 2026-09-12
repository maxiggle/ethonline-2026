# TICKET X402-003: Agent Demo Client (x402 v2 + Guardian + Ledger)

**Lane:** A · **Time box:** 1.5 h · **Component:** `scripts/` · **Depends on:** LEDGER-001 (package + key loading), X402-002 contract · **Read first:** `docs/tickets/README.md`

## Why
This is the demo. An autonomous agent discovers paid x402 resources and asks the Guardian before paying:
- ALLOW → pays with its Key Ring-protected wallet;
- ESCALATE → waits for a Ledger-signed payment;
- BLOCK → refuses.

Every settlement is reported back and verified on-chain.

## Implementation
Rewrite `scripts/agent-x402-client.ts` (the old version targets the legacy `/vendor/*` rail) plus helpers in `scripts/lib/`.

1. **Env** (all required): `API_BASE_URL`, `WALLET_PASS`, `AGENT_KEY_RING_FILE`, `AGENT_KEY_RING_KEY_NAME`.
   - Load the agent account with `loadAgentAccount()` from LEDGER-001.
   - Fetch `GET /x402/approvals/config` for `approverAddress`.
2. **`scripts/lib/agent-request.ts`:** `signedAgentFetch(account, method, path, body?)` implements exactly the `AgentSignatureGuard` scheme from X402-002. The body hash is the sha256 of the exact JSON string sent.
3. **x402 SDK:** use `@x402/fetch` / `@x402/core/client` / `@x402/evm/exact/client` (pinned). Read the installed types for:
   - how to parse the `402` `PAYMENT-REQUIRED` response (e.g. `x402HTTPClient`);
   - the EVM client signer interface expected by `registerExactEvmScheme` (an object with `address` and `signTypedData`, or a viem account; confirm);
   - whether the client exposes lifecycle hooks that run before a payment payload is created.
4. **Payment flow per resource** (guarantee exactly one authorization per payment):
   1. `fetch(resourceUrl)` returns `402`. Decode the requirements and pick the one with `network === 'eip155:84532'` and the USDC asset.
   2. `POST /x402/payments/authorize` with `{ resourceUrl, paymentRequirements, justification }`.
   3. Act on the decision:
      - **BLOCK:** print the reasons and stop; no signature is created.
      - **ALLOW:** create the payment with a client whose signer is the Key Ring agent account, and retry the request.
      - **ESCALATE:** create the payment with a client whose signer is a **Ledger remote signer**: `{ address: approverAddress, signTypedData: async (typedData) => { POST /x402/payments/:actionId/escalation { typedData }; poll GET /x402/payments/:actionId every 3 s (10 min timeout) until escalationStatus === 'SIGNED' → return signature; 'REJECTED' → throw } }`. Print "Waiting for approval on Ledger console…".
   4. On `200`, decode `PAYMENT-RESPONSE` for the transaction hash and call `POST /x402/payments/:actionId/settlement { transactionHash }`.
   5. Print the response data and `https://base-sepolia.blockscout.com/tx/<hash>`.

   If the SDK only offers `wrapFetchWithPayment`, make sure its automatic retry doesn't bypass or duplicate the authorization step. Either use a hook, or build the payload manually with the client and set the `PAYMENT-SIGNATURE` header yourself.
5. **Scenarios** (`--scenario=allow|escalate|block|all`, default `all`), with a narrated console output suitable for the demo video:
   - **allow:** `GET /x402/weather?city=Lagos` ($0.01) → ALLOW → paid by the agent wallet → real weather data.
   - **escalate:** `GET /x402/chain-report` ($2.00, above `X402_AUTONOMOUS_LIMIT`) → ESCALATE → approve in the Ledger console → paid from the Ledger address → real chain data.
   - **block:** `GET /x402/partner-feed` (unapproved payee) → BLOCK → no signature.
6. **Before each payment**, print the agent's and the Ledger's USDC balances (viem `readContract` `balanceOf` on Base Sepolia).
7. **Tests:**
   - `signedAgentFetch` message and hash construction, verified against the backend guard's format with a fixed key.
   - The decision branching, with mocked HTTP.
   - `npm --prefix scripts run typecheck` passes.

## Acceptance criteria
- **All scenarios run live:** against a local backend (X402-001/002) with the Ledger console open, `WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w) AGENT_KEY_RING_FILE=~/.chapter2/agent-key.enc AGENT_KEY_RING_KEY_NAME=chapter2-x402-agent API_BASE_URL=http://localhost:3001 npm --prefix scripts run demo:x402` completes all three:
  - two real Base Sepolia settlements (one from the agent wallet, one from the Ledger address), both verified by the backend;
  - one BLOCK with no signature.
- **Commits** (for example):
  - `feat(client): pay x402 v2 resources through the Guardian with Key Ring and Ledger signers`
  - `test(client): cover agent request signing and decision branching`
