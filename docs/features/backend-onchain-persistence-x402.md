# Feature Documentation: Persistence, On-Chain Relayer, and x402 Payment Loop

> **Partly outdated.** Persistence still applies. The on-chain relayer was removed (the executor is read-only), and the `/vendor/*` rail is legacy. Current architecture: [ARCHITECTURE.md](../ARCHITECTURE.md).

## 1. Overview
Ticket `CH2-CORE-001` transitions Chapter 2 from an ephemeral in-memory simulation to a live, production-grade autonomous treasury management system. It delivers:
1. **Dual-Mode Persistence (SQLite & PostgreSQL)**: Write-through persistence for actions, mandates, daily budget tracking, and World ID bindings with 0 data loss across service restarts.
2. **On-Chain Safe Relayer (`OnChainExecutorService`)**: Direct broadcast of autonomous and escalated transactions to Base Sepolia (`chainId: 84532`) via `Chapter2Guard` and Safe multisig with verified on-chain execution receipts.
3. **Strict Zero-Fallback Configuration**: Guaranteed fail-fast behavior with no fallback private keys or dummy contract addresses.
4. **x402 Payment Protocol Integration**: Standard HTTP 402 Payment Required challenge and unlock loop for autonomous AI compute allocations.

---

## 2. Architecture & Modules

### A. Database Persistence Layer (`backend/src/database/`)
* **Module**: `DatabaseModule` (Global)
* **Service**: `DatabaseService`
* **Drivers**: Synchronous SQLite (`better-sqlite3`) for local development and async PostgreSQL (`pg`) for containerized deployment via `docker-compose.yml`.
* **Schemas**:
  1. `treasury_actions`: Stores proposal lifecycle (`PENDING`, `APPROVED`, `REJECTED`, `EXECUTED`), EIP-712 approval signatures, risk scores, and mined `tx_hash`es.
  2. `treasury_mandates`: Stores chain ID, Safe address, Guard address, autonomous agent, human signer, and JSON-encoded whitelists.
  3. `daily_spent_ledger`: Stores calendar day epochs (`Math.floor(timestamp / 86400)`) and cumulative autonomous spend to protect rolling 24-hour budgets across restarts.
  4. `human_bindings`: Stores World ID Credential 11 nullifier hashes, human signer addresses, and 90-day expiry timestamps.

### B. On-Chain Safe Relayer (`backend/src/blockchain/`)
* **Module**: `BlockchainModule` (Global)
* **Service**: `OnChainExecutorService`
* **Live Network**: Base Sepolia (`chainId: 84532`, RPC: `https://sepolia.base.org`)
* **Deployed Contracts**:
  * `Chapter2Guard`: `0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3`
  * `MockSafe`: `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6`
  * Relayer Signer: `0x988B225185b516DEF12A7Ec841abae9072ef4EE8`
* **Execution Flow**:
  1. `executeAutonomousPayment`: Routes transfers where `amount <= maxAutonomousAmount` to whitelisted recipients through `Safe.execTransaction()`.
  2. `executeEscalatedPayment`: Submits human EIP-712 approval payloads to Safe, which invokes `Chapter2Guard.checkTransaction()`, marks nonces, and settles.
  3. `runWithMutex`: FIFO queue preventing nonce collisions during concurrent transaction preparation.
  4. `verifyTransaction`: Queries Base Sepolia provider for confirmed receipts (`status === 1`).

### C. Zero-Fallback Security Policy
* All sensitive credentials and network parameters must be supplied via `process.env`.
* Missing `RPC_URL`, `SAFE_ADDRESS`, `GUARD_ADDRESS`, or `CHAIN_ID` causes the service to throw an immediate exception during startup.
* No dummy private keys or addresses are hardcoded in code.

### D. x402 Payment Protocol (`backend/src/vendor/`)
* **Module**: `VendorModule`
* **Controller**: `VendorController` (`GET /vendor/compute`, `GET /vendor/bills/:id`, `GET /vendor/weather`)
* **Service**: `VendorService`
* **Protocol Challenge**:
  * Request without payment returns `HTTP 402 Payment Required` with headers:
    * `X-Payment-Address`: Vendor payment recipient (`0x0000000000000000000000000000000000041c4e`)
    * `X-Payment-Amount`: Required amount in base units (`40000000`, 40 USDC)
    * `X-Payment-Token`: Approved token contract address
    * `X-Payment-ChainId`: Network chain ID (`84532`)
* **Protocol Unlock**:
  * Retrying with `X-Payment-TxHash: 0x...` redeems the payment (see section E) and returns `HTTP 200 OK` with session tokens and dedicated GPU cluster allocations.

### E. x402 On-Chain Payment Verification & Replay Protection (SEC-004)
Every x402 resource (`vendor:compute`, `vendor:weather`, and each `bill:<id>`) unlocks only after a
verified ERC-20 transfer, and every tx hash can be redeemed exactly once, across all resources.

* **Schema**: `x402_payment_receipts (tx_hash PK, resource, amount, redeemed_at)` in `DatabaseService`
  (same dual-mode SQLite/PostgreSQL persistence as the other tables). Keys are lowercased. The insert
  is `INSERT ... ON CONFLICT (tx_hash) DO NOTHING`, so a duplicate hash returns `changes: 0`.
* **On-chain verification**: `OnChainExecutorService.verifyTokenTransfer(txHash, { token, recipient, minimumAmount })`
  fetches the receipt, rejects a missing or reverted (`status !== 1`) receipt, decodes ERC-20
  `Transfer` logs matching `token` and `to == recipient`, sums their `value`, and verifies only when
  the sum is `>= minimumAmount`.
* **`VendorService.redeemPayment(txHash, requirements, resourceId)`**: the single choke point for
  unlocking any resource.
  1. Rejects a malformed hash (`/^0x[0-9a-fA-F]{64}$/`) or a `chainId` mismatch.
  2. Rejects a hash already present in `x402_payment_receipts`.
  3. Calls `verifyTokenTransfer`; rejects on failure.
  4. Inserts the receipt; a concurrent `changes: 0` is also rejected as a replay.
  5. Returns the lowercased hash, used everywhere downstream instead of the caller-supplied one.
* **Callers**: `verifyAndGrantAccess` (compute, resource `vendor:compute`), `getPaidWeatherTelemetry`
  (weather, resource `vendor:weather`), and `settleBillWithPayment` (per-bill, resource `bill:<id>`,
  idempotent for a repeat of the same hash, rejected for a different one once settled).
* **`invokeService`** matches the resource by URL path exactly (404 on no match), validates params
  (e.g. weather requires `city`) before proposing a payment, and returns a status union of
  `SUCCESS | ESCALATED | BLOCKED | PENDING_SETTLEMENT` (`PENDING_SETTLEMENT` when the proposed action
  has no `txHash` yet, since autonomous execution is asynchronous) instead of always reporting `SUCCESS`.

**Known limitation**: replay protection is atomic only within a single backend instance. The
in-memory `x402PaymentReceipts` map is checked and inserted synchronously, but the PostgreSQL
`ON CONFLICT` write happens on a fire-and-forget background call (`asyncWriteToPostgres`). With
several backend instances behind a load balancer, two instances could both pass the in-memory
uniqueness check for the same hash before either write reaches Postgres, redeeming one payment
twice. This is not fixed here; running multiple instances needs a synchronous, database-backed
compare-and-insert instead.

---

## 3. Verification & Test Coverage
* Automated tests run via `npm test` (`jest --runInBand --forceExit`).
* Covers duplicate-receipt rejection, `verifyTokenTransfer` (valid payment, wrong recipient, wrong
  token, underpayment, reverted receipt, missing receipt), and `VendorController`/`VendorService`
  redemption, replay, and settlement behavior.
* `OnChainExecutorService`'s broadcasting spec is tested separately against live Base Sepolia RPC
  and deployed contracts; it is excluded from routine runs (`--testPathIgnorePatterns on-chain-executor`).
