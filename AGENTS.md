# Agent Directives & Zero Fallback Rule

## Strict Zero Fallback Policy
Under NO circumstances shall hardcoded fallbacks, dummy mock values, simulated balances, or fake users be introduced into the application.

1. **Authentication Gate:**
   - If authentication fails, is cancelled, or is unsupported, the user MUST NOT pass the authentication screen.
   - Never synthesize dummy fallback users, mock DIDs (`did:privy:google_user`), or fake bearer tokens in runtime code.
   - Throw explicit errors (`UnsupportedError`, `UnauthorizedException`) so errors are real and visible.

2. **No Hardcoded Balances or Metrics:**
   - Balances, daily caps, spent budgets, active agents, and transaction counts MUST be retrieved dynamically from live APIs or on-chain RPC.
   - Never hardcode placeholder numbers (e.g. `150000.0`, `140 / 500 USDC`, or progress values like `0.28`).
   - If data is loading, display a clean loading indicator. If loading fails, display the actual error state.

3. **Real Blockchain Receipts Only:**
   - Transaction hashes, signatures, and execution receipts must come exclusively from verified cryptographic signatures and mined on-chain transactions.
   - Never use placeholder hashes (e.g. `0x7e8b...`) or dummy signatures.
