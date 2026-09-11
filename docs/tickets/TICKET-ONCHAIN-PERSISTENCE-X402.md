# TICKET-CH2-CORE-001: Implement SQLite Persistence, On-Chain Relayer, and x402 Payment Pattern

## 1. Ticket Overview
- **Ticket ID**: `CH2-CORE-001`
- **Component**: `backend/` (NestJS, Ethers v6, SQLite)
- **Priority**: High / Critical Demo Milestone
- **Goal**: Transition Chapter 2 from an in-memory simulation to a live, persistent autonomous payment system by adding:
  1. SQLite database persistence for actions, mandates, daily budget tracking, and human signer bindings.
  2. An on-chain transaction execution relayer that broadcasts real Safe / ERC-20 transfers to Base Sepolia (or local Anvil) and records verified transaction hashes (`txHash`).
  3. An **x402 (HTTP 402 Payment Required)** demonstration service and autonomous agent client loop proving real-world AI payments under human supervisory control.

---

## 2. Background & Problem Statement
1. **No Persistence**: `ActionStoreService`, `PolicyEngineService`, and `WorldSelfieService` currently use in-memory `Map` data structures. Rebooting the backend wipes the action history, resets the rolling daily spend counter (a security flaw), and loses the World ID 90-day human binding.
2. **Missing On-Chain Execution**: When an action is evaluated as `ALLOW` or approved via human clear-signing (`POST /actions/:id/approve`), the backend computes the ABI-encoded payload, but never broadcasts it via an Ethereum RPC provider. As a result, no real tokens move on-chain and `txHash`es remain mocked.
3. **No Realistic Payment Consumer (x402)**: We need a clear, real-world demonstration of *why* the autonomous agent needs treasury funds. The industry-standard **x402 (HTTP 402 Payment Required)** pattern shows the agent attempting to access a paid resource, receiving a 402, routing through Chapter 2's Guardian for cap enforcement, paying on-chain, and unlocking the resource with HTTP 200.

---

## 3. Scope of Work & Deliverables

### Module A: SQLite Persistence Layer
- **Target Directory**: `backend/src/database/` (or integrate via TypeORM / SQLite driver).
- **Database File**: `backend/data/chapter2.sqlite` (add `backend/data/*.sqlite` to `.gitignore`).
- **Required Schemas / Tables**:
  1. `treasury_actions`:
     - `id` (string, PK)
     - `target` (string)
     - `value` (string)
     - `data` (string)
     - `token` (string)
     - `recipient` (string)
     - `amount` (string)
     - `agent_address` (string)
     - `justification` (text)
     - `status` (string: `PENDING`, `APPROVED`, `REJECTED`, `EXECUTED`, `EXPIRED`)
     - `risk_score` (integer)
     - `requires_human_approval` (boolean)
     - `nonce` (integer)
     - `deadline` (integer)
     - `signature` (string, nullable)
     - `tx_hash` (string, nullable)
     - `created_at` (datetime)
     - `updated_at` (datetime)
  2. `treasury_mandates`:
     - `chain_id` (integer)
     - `safe_address` (string)
     - `guard_address` (string)
     - `autonomous_agent` (string)
     - `human_signer` (string)
     - `max_autonomous_amount` (string / bigint)
     - `daily_autonomous_limit` (string / bigint)
     - `approved_recipients` (JSON string / text array)
     - `approved_tokens` (JSON string / text array)
     - `updated_at` (datetime)
  3. `daily_spent_ledger`:
     - `day_id` (integer, e.g. `Math.floor(timestamp / 86400)`, PK)
     - `cumulative_spent` (string / bigint)
     - `updated_at` (datetime)
  4. `human_bindings`:
     - `signer_address` (string, PK)
     - `nullifier_hash` (string)
     - `bound_at` (datetime)
     - `expires_at` (datetime)
- **Refactoring**:
  - Update `ActionStoreService` to query and mutate SQLite instead of in-memory `Map`.
  - Update `PolicyEngineService` to persist mandate updates and daily spending tallies to SQLite.
  - Update `WorldSelfieService` to persist 90-day human bindings to SQLite.

---

### Module B: On-Chain Execution Relayer (`OnChainExecutorService`)
- **Target Directory**: `backend/src/blockchain/` (or `backend/src/crypto/`).
- **Configuration**:
  - `RPC_URL`: `process.env.RPC_URL || 'https://sepolia.base.org'` (or local Anvil `http://127.0.0.1:8545`).
  - `RELAYER_PRIVATE_KEY`: Private key funded with testnet ETH on Base Sepolia.
  - `SAFE_ADDRESS`: `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6`.
  - `GUARD_ADDRESS`: `0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3`.
- **Implementation**:
  1. `executeAutonomousPayment(action: TreasuryAction)`:
     - When an action is evaluated as `ALLOW`, the relayer executes the transaction through the Safe.
     - Calls `safe.execTransaction(...)` passing the autonomous ERC-20 transfer parameters.
     - Safe triggers `Chapter2Guard.checkTransaction()`, which validates that `amount <= maxAutonomousAmount` and `recipient` is whitelisted.
     - Waits for confirmation: `const receipt = await tx.wait()`.
     - Updates `action.status = TreasuryActionStatus.EXECUTED` and `action.txHash = receipt.hash`.
     - Emits WebSocket event `action:executed` with real `txHash`.
  2. `executeEscalatedPayment(action: TreasuryAction, signatureHex: string)`:
     - When human operator clear-signs via Ledger (`POST /actions/:id/approve`), the relayer packs the EIP-712 approval struct and signature bytes.
     - Calls `safe.execTransaction(...)` passing the packed signatures byte array.
     - Safe triggers `Chapter2Guard.checkTransaction()`, which calls `_verifyEscalatedSignature()`.
     - Recovers human signer, marks nonce as used, and transfers tokens.
     - Waits for receipt, records `txHash`, and updates status to `EXECUTED`.

---

### Module C: x402 Payment Pattern Integration & Demo Loop
- **Target Directory**: `backend/src/vendor/` and a standalone runnable demo client `scripts/agent-x402-client.ts`.
- **Flow**:
  1. **Vendor Service Endpoint (`GET /vendor/compute` or `POST /vendor/query`)**:
     - Inspects `req.headers['authorization']` or `req.headers['x-payment-txhash']`.
     - If no valid payment hash is provided, returns **`HTTP 402 Payment Required`**:
       ```http
       HTTP/1.1 402 Payment Required
       X-Payment-Required: true
       X-Payment-Address: 0x0000000000000000000000000000000000041c4e
       X-Payment-Amount: 40000000
       X-Payment-Token: 0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6
       X-Payment-ChainId: 84532
       X-Payment-Justification: Dedicated RPC Node Compute Slot
       ```
       JSON Body:
       ```json
       {
         "error": "Payment Required",
         "statusCode": 402,
         "paymentRequirements": {
           "recipient": "0x0000000000000000000000000000000000041c4e",
           "amount": "40000000",
           "token": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
           "chainId": 84532,
           "justification": "Dedicated RPC Node Compute Slot"
         }
       }
       ```
  2. **Payment Verification**:
     - When client retries with `X-Payment-TxHash: 0x...`:
     - The vendor service verifies on Base Sepolia (or against backend action store) that the transaction transferred $\ge 40$ USDC to the vendor address.
     - If verified, returns **`HTTP 200 OK`** with the unlocked resource payload:
       ```json
       {
         "status": "SUCCESS",
         "data": {
           "slotId": "compute-dedicated-001",
           "uptime": "99.99%",
           "unlockedAt": "2026-09-11T14:30:00Z",
           "receiptTx": "0x7e8b..."
         }
       }
       ```
  3. **Autonomous Agent Client Script (`scripts/agent-x402-client.ts`)**:
     - Demonstrates the end-to-end autonomous loop:
       1. Agent requests `/vendor/compute` -> gets HTTP 402.
       2. Agent extracts payment requirements and calls `POST http://localhost:3001/actions/propose`.
       3. Chapter 2 Guardian evaluates $40 $\le$ $100 cap -> `ALLOW` -> relayer executes payment on Base Sepolia -> returns `txHash`.
       4. Agent calls `/vendor/compute` with `X-Payment-TxHash: 0x...` -> gets HTTP 200 OK!
       5. (Secondary scenario): Agent requests high-tier service ($850) -> gets HTTP 402 -> calls Chapter 2 -> `ESCALATE` -> pauses until mobile supervisor signs with Ledger -> once signed and executed, unlocks service.

---

## 4. Existing On-Chain Contracts Reference
- **Network**: Base Sepolia (`chainId: 84532`)
- **Safe Multisig**: `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6`
- **Chapter 2 Guard**: `0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3`
- **Autonomous Agent**: `0x1111111111111111111111111111111111111111`
- **Authorized Hardware Signer**: `0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7`
- **Approved Vendor Recipient**: `0x0000000000000000000000000000000000041c4e`
- **Approved USDC Token**: `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6`

---

## 5. Acceptance Criteria
1. **Persistence Verification**:
   - Propose an action, update a mandate, and bind a World ID signer.
   - Restart the NestJS server (`Ctrl+C` and `npm start`).
   - Call `GET /actions` and `GET /mandates/active`: all previous data and cumulative daily spend must persist without data loss.
2. **On-Chain Relayer Execution**:
   - Actions evaluated as `ALLOW` or approved via Ledger execute on Base Sepolia (or local Anvil).
   - Real transaction receipts are captured and `action.txHash` is populated with a valid transaction hash.
3. **x402 Protocol Proof**:
   - Running `npx ts-node scripts/agent-x402-client.ts` triggers the full loop:
     - 402 Payment Required -> Proposal -> Guardian ALLOW -> On-Chain Settlement -> 200 Resource Unlocked.
4. **Test Suite Health**:
   - `cd backend && npm test` passes with 100% test coverage for new modules.
