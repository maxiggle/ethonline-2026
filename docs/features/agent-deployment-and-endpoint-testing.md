# Agent Deployment, Mandate Spending Caps & End-to-End Testing Walkthrough

## 1. Overview
This document specifies the exact supervisory endpoints, execution flows, and end-to-end testing procedures for the **Chapter 2** institutional command center. It also details the step-by-step lifecycle of **deploying a new autonomous AI treasury agent and assigning its spending caps** across the smart contract guard (`Chapter2Guard.sol`), the supervisory backend (`backend/`), native hardware security (`packages/`), and the mobile command center (`chapter2/`).

---

## 2. API Endpoints Catalog (What We Will Call)

During end-to-end testing, the client (mobile command center, CLI runner, or test harness) interacts with the running supervisory backend via HTTP REST and real-time Socket.io WebSocket streaming.

### A. Actions & Tri-Verdict Endpoints (`/actions`)

| Method | Endpoint | Purpose | Request Body / Params | Expected Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/actions/propose` | Ingests a new transaction proposed by an autonomous agent. Evaluates deterministic limits, balance reservation, and guardian risk score. | `ProposeActionDto`:<br>`target` (address)<br>`value` (wei string)<br>`data` (hex bytes)<br>`token` (address)<br>`recipient` (address)<br>`amount` (base units string)<br>`agentAddress` (address)<br>`justification` (string)<br>`worldIdProof?` (optional ZK proof) | `ActionResponseDto`:<br>`action`: `TreasuryAction`<br>`decision`: `GuardianDecision` (`ALLOW` \| `ESCALATE` \| `BLOCK`)<br>`typedData?`: `Eip712ApprovalPayload` (if escalated) |
| `GET` | `/actions` | Lists all actions across the treasury timeline. | Query: `?status=PENDING\|APPROVED\|REJECTED` | `TreasuryAction[]` |
| `GET` | `/actions/pending` | Retrieves actions held in `PENDING` state awaiting human hardware authorization. | None | `TreasuryAction[]` |
| `GET` | `/actions/:id` | Inspects full action details, current status, and risk analysis breakdown. | Param: `:id` | `TreasuryAction` |
| `GET` | `/actions/:id/clear-sign` | Generates a transparent clear-signing prompt preventing blind signing on device screens. | Param: `:id` | `LedgerClearSignPrompt`:<br>`title`, `lines`, `warningLevel`, `summary` |
| `POST` | `/actions/:id/approve` | Submits human supervisor's cryptographic EIP-712 approval signature. Validates signer against authorized hardware/World ID and commits balance reservation. | `SubmitApprovalDto`:<br>`actionId` (string)<br>`signature` (65-byte hex)<br>`signer` (address)<br>`biometricVerified?` (boolean) | `{ action: TreasuryAction, encodedPayload: string, signer: string }` |
| `POST` | `/actions/:id/reject` | Operator vetoes an action. Releases balance reservation and transitions action to `REJECTED`. | `RejectActionDto`:<br>`reason` (string) | `{ action: TreasuryAction, rejected: true, reason: string }` |

### B. Hardware & LKRP Key Ring Endpoints (`/ledger`)

| Method | Endpoint | Purpose | Request Body | Expected Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/ledger/status` | Reports hardware connection status, mode (`MOCK_HARDWARE` / `HEADLESS_CLI` / `BLE`), and derivation path. | None | `LedgerDeviceStatus` |
| `GET` | `/ledger/signer` | Fetches checksummed authorized hardware signer address (`0xe05fcC23...`). | None | `{ address: string }` |
| `POST` | `/ledger/clear-sign-prompt` | Formats clear-signing layout for approval payload. | `SignApprovalDto` | `LedgerClearSignPrompt` |
| `POST` | `/ledger/sign` | Generates hardware/mock signature over typed EIP-712 domain. | `SignApprovalDto` | `KeyRingSignResult` |

### C. World ID Credential 11 (Selfie Check) Endpoints (`/world/selfie`)

| Method | Endpoint | Purpose | Request Body | Expected Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/world/selfie/verify` | Directly validates World ID Credential 11 zero-knowledge proof. | `VerifySelfieDto` | `SelfieVerificationResult` |
| `POST` | `/world/selfie/bind` | Binds human nullifier to signer address with a 90-day inactivity window. | `BindSelfieDto` | `HumanBinding` |
| `GET` | `/world/selfie/status/:signer` | Verifies whether a signer address holds active, non-expired human proof. | Param: `:signer` | `{ isVerified: boolean, binding: HumanBinding }` |

### D. WebSocket Event Streaming (`/`)

The Socket.io gateway provides real-time bi-directional events:
- **Client Emits**: `subscribe:actions` (joins `actions_channel`), `ping` (heartbeat).
- **Server Emits**:
  - `action:proposed`: Ingestion notification.
  - `action:escalated`: Triggers push notification to mobile command center with clear-sign prompt.
  - `action:approved`: Broadcasts successful human authorization and Safe execution bytes.
  - `action:blocked`: Emits adversarial block alert.
  - `action:rejected`: Broadcasts operator rejection.

---

## 3. How We Intend to Test (Execution Flow & Test Harness)

Testing the live system without relying merely on unit test mocks involves three distinct operational scenarios:

```
                                  [Autonomous AI Agent]
                                            │
                                            ▼
                                   POST /actions/propose
                                            │
                                            ▼
                                ┌───────────────────────┐
                                │ Guardian Orchestrator │
                                └───────────┬───────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
             [Scenario 1: $40]      [Scenario 2: $850]      [Scenario 3: $5,000]
              Within Cap ($100)      Exceeds Cap ($100)      Unapproved Recipient
                    │                       │                       │
                    ▼                       ▼                       ▼
                 Verdict:                Verdict:                Verdict:
                  ALLOW                  ESCALATE                 BLOCK
                    │                       │                       │
             Auto-executed                  ▼                  Rejected
              on Safe Guard          WebSocket Alert        Reservation Freed
                                    to Mobile Command
                                            │
                                            ▼
                                  Human Clear-Sign Review
                                            │
                                            ▼
                                   Biometric Validation
                                   (World ID / Enclave)
                                            │
                                            ▼
                                  Ledger Physical Sign
                                            │
                                            ▼
                                   POST /actions/approve
                                            │
                                            ▼
                                    Approved & Executed
```

### Scenario 1: Autonomous ALLOW ($40 RPC bill)
1. **Target**: Pre-approved vendor (`0x0000000000000000000000000000000000041c4e`).
2. **Payload**:
   ```json
   {
     "target": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
     "value": "0",
     "data": "0xa9059cbb...",
     "token": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
     "recipient": "0x0000000000000000000000000000000000041c4e",
     "amount": "40000000",
     "agentAddress": "0x1111111111111111111111111111111111111111",
     "justification": "Alchemy monthly RPC node infrastructure"
   }
   ```
3. **Execution**:
   - `PolicyEngineService` verifies amount ($40) is within single cap ($100) and daily cap ($500).
   - Balance reservation acquires 40 USDC.
   - Guardian assigns risk score ~15.
   - Action marked `APPROVED`, reservation committed, autonomous execution emitted.

### Scenario 2: Escalated Clear-Sign ($850 Cluster Renewal)
1. **Target**: Pre-approved vendor, but amount exceeds $100 autonomous cap.
2. **Payload**: `amount: "850000000"` ($850 USDC).
3. **Execution**:
   - `PolicyEngineService` detects `amount > maxAutonomousAmount`.
   - Decision evaluated as `ESCALATE` (risk score ~78).
   - Action marked `PENDING`.
   - EIP-712 typed payload generated:
     ```json
     {
       "actionId": "act_...",
       "agent": "0x1111...",
       "recipient": "0x0000...41c4e",
       "token": "0x4f71...1df6",
       "amount": "850000000",
       "nonce": 101,
       "deadline": 1800000000,
       "mandateHash": "0x...",
       "riskScore": 78
     }
     ```
   - WebSocket event `action:escalated` pushes prompt to mobile device.
   - Device validates human biometrics, Ledger signs EIP-712 digest.
   - Client calls `POST /actions/:id/approve` with signature.
   - Backend verifies signature against `0xe05fcC23...` (hardware signer), commits reservation, emits `action:approved`.

### Scenario 3: Malicious BLOCK ($5,000 Drain)
1. **Target**: Unknown recipient (`0x8F0000000000000000000000000000000000072A`).
2. **Payload**: `amount: "5000000000"` ($5,000 USDC).
3. **Execution**:
   - `PolicyEngineService` detects recipient is not on whitelist.
   - Decision evaluated as `BLOCK` (risk score 100, reason `RecipientNotApproved`).
   - Action marked `REJECTED`, reservation released.
   - WebSocket event `action:blocked` triggers red security alert.

---

## 4. How We Deploy a New Agent and Assign Its Cap (Comprehensive Walkthrough)

Deploying a new autonomous AI treasury agent in Chapter 2 involves a coordinate lifecycle across the **Smart Contract Guard**, the **Supervisory Backend Engine**, and the **Mobile Command Center**:

```
 ┌────────────────┐       ┌────────────────┐       ┌────────────────┐
 │     MOBILE     │       │    BACKEND     │       │ SMART CONTRACT │
 │ COMMAND CENTER │       │ POLICY ENGINE  │       │ CHAPTER2 GUARD │
 └───────┬────────┘       └───────┬────────┘       └───────┬────────┘
         │                        │                        │
  1. Supervisor inputs            │                        │
     Agent Address & Caps         │                        │
         │                        │                        │
  2. Ledger Clear-Sign            │                        │
     Mandate Transaction          │                        │
         │                        │                        │
  3. Submit to On-Chain ──────────┼───────────────────────►│
     Safe Transaction             │                        │
         │                        │                 guard.setAutonomousAgent()
         │                        │                 guard.updateMandateLimits()
         │                        │                        │
  4. Register Mandate ───────────►│                        │
     POST /mandates/agent         │                        │
         │                        │                        │
  5. World ID ───────────────────►│                        │
     Proof-of-Personhood          │                        │
     POST /world/selfie/bind      │                        │
         │                        │                        │
  6. Agent Deployed & Active      │                        │
     Ready for Autonomous Spend   │                        │
```

### Layer 1: Smart Contract Level (`Chapter2Guard.sol`)

The treasury funds reside inside an institutional Safe multi-sig contract (`safeAddress`). `Chapter2Guard.sol` implements Safe's `ITransactionGuard` interface, intercepting every execution before it touches assets.

1. **Setting the Autonomous Agent**:
   ```solidity
   function setAutonomousAgent(address _agent) external onlyOwner;
   ```
   - Only the contract owner (the Safe itself or the security governance key) can execute this.
   - Stores the authorized address in the state variable `autonomousAgent`.

2. **Assigning Spending Caps**:
   ```solidity
   function updateMandateLimits(uint256 _maxPerTx, uint256 _dailyLimit) external onlyOwner;
   ```
   - `_maxPerTx`: The maximum amount an agent can execute autonomously in a single transaction without human intervention (e.g. `100_000_000` = 100 USDC with 6 decimals).
   - `_dailyLimit`: The rolling 24-hour aggregate budget allocated to autonomous operations (e.g. `500_000_000` = 500 USDC).
   - Emits `MaxAutonomousAmountUpdated` and `DailyAutonomousLimitUpdated`.

3. **Whitelisting Recipients and Tokens**:
   ```solidity
   function setApprovedRecipient(address recipient, bool approved) external onlyOwner;
   function setApprovedToken(address token, bool approved) external onlyOwner;
   ```
   - Restricts agent spending strictly to authorized vendor addresses (e.g. Alchemy, Infura, AWS) and approved treasury assets (e.g. USDC).

4. **On-Chain Enforcement Mechanics**:
   When the agent calls `safe.execTransaction()`:
   - Safe delegates to `guard.checkTransaction(to, value, data, ..., msgSender)`.
   - If `msgSender == autonomousAgent`:
     - Checks `isApprovedToken[token]` (reverts `TokenNotApproved` if false).
     - Checks `isApprovedRecipient[recipient]` (reverts `RecipientNotApproved` if false).
     - Checks `amount <= maxAutonomousAmount` (reverts `ExceedsAutonomousLimit` if no valid human signature attached).
     - Checks `dailySpent[dayId] + amount <= dailyAutonomousLimit` (reverts `ExceedsDailyLimit` if exceeded).
     - If all pass: updates `dailySpent[dayId] += amount`, emits `AutonomousActionExecuted`, and allows Safe to execute.

---

### Layer 2: Supervisory Backend Level (`PolicyEngineService`)

The backend orchestrator monitors the agent's intent before transactions reach the blockchain, preventing failed gas consumption, front-running, and unauthorized state bloat.

1. **Mandate Registration & Configuration**:
   The `TreasuryMandate` entity defines:
   ```typescript
   export interface TreasuryMandate {
     chainId: number;
     safeAddress: string;
     guardAddress: string;
     autonomousAgent: string;         // The newly deployed agent address
     humanSigner: string;             // The authorized hardware signer address
     maxAutonomousAmount: bigint;     // e.g. 100000000n (100 USDC)
     dailyAutonomousLimit: bigint;    // e.g. 500000000n (500 USDC)
     approvedRecipients: string[];    // Whitelisted addresses
     approvedTokens: string[];        // Whitelisted token contracts
   }
   ```

2. **Atomic Balance Reservation System**:
   - Autonomous agents may operate concurrently or dispatch bursts of micro-transactions.
   - To prevent multiple concurrent proposals from simultaneously bypassing the daily cap (a classic TOCTOU race condition), `BalanceReservationService` allocates an in-memory reservation lock when an action is proposed.
   - If `currentDailySpent + currentActiveReservations + requestedAmount > dailyLimit`, the reservation fails immediately, rejecting the proposal before risk analysis.

3. **Human Signer Binding & 90-Day Liveness Window**:
   - The supervisor's signing address is cryptographically anchored to World ID Credential 11 (Selfie Check Beta).
   - The backend records `HumanBinding`:
     - `signerAddress`: Hardware key.
     - `nullifierHash`: Zero-knowledge identity nullifier.
     - `boundAt`: Initial timestamp.
     - `expiresAt`: `boundAt + 90 days`.
   - If 90 days elapse without biometric re-verification, escalated transactions from this supervisor are locked.

---

### Layer 3: Mobile Command Center Supervisor Interface (`chapter2`)

The mobile command center provides an institutional cockpit where human supervisors configure, monitor, and deploy agents without touching low-level terminal scripts:

1. **Agent Setup & Cap Assignment Screen (`onboarding_screen.dart` & `mandate_management_sheet.dart`)**:
   - During user onboarding (Step 2: Create Treasury Agent), the app retrieves the user's live **Privy Embedded EVM Wallet** (`user.walletAddress`) backed by secure enclaves.
   - Enters agent parameters:
     - **Agent Label**: "Autonomous Treasury Agent" (customizable)
     - **Agent Ethereum Address**: Dynamically provisioned by Privy (e.g., `0x42AbC...`)
     - **Single Autonomous Limit**: `$100.00 USDC`
     - **Daily Autonomous Budget**: `$500.00 USDC`
     - **Whitelisted Recipient**: `0x0000000000000000000000000000000000041c4e`
     - **Whitelisted Token**: `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6`

2. **Hardware Clear-Signing Protocol**:
   - To ensure the mobile device itself cannot be compromised to arbitrarily elevate agent caps, changes to the mandate require a multi-sig on-chain transaction or an EIP-712 signed mandate update.
   - The mobile app connects to the **Ledger device via BLE** (`packages/ledger_keyring`) or prompts **Apple Secure Enclave / Android StrongBox KeyMint**.
   - The Ledger device displays the clear-sign prompt:
     ```
     [Ledger Stax / Flex Display]
     Review Mandate Update:
     Agent: 0x42Ab...cDeF
     Single Cap: 100 USDC
     Daily Cap: 500 USDC
     Recipient: 0x0000...41c4e
     Hold to Confirm
     ```
   - The physical confirmation guarantees non-repudiation.

3. **World ID Selfie Check Binding (`onboarding_screen.dart`)**:
   - Supervisor performs facial liveness scan via `packages/agent_security`.
   - Native plugin generates zero-knowledge proof of personhood (Credential 11).
   - Proof is transmitted to `POST /world/selfie/bind`, establishing the 90-day supervisory perimeter.

---

### Layer 4: Practical Step-by-Step Deployment Walkthrough

Here is the exact procedure to deploy an agent and assign its cap during live system operation:

#### Step 1: User Sign-In & Privy Embedded Wallet Provisioning
```bash
# Upon Privy login (OAuth / Email), Privy SDK provisions an EVM embedded wallet
PRIVY_WALLET_ADDRESS="0x42AbCdEf01234567890123456789012345678901"
```

#### Step 2: Bind Agent & Synchronize On-Chain Guard
When the user submits Step 2 of the Onboarding Wizard, the mobile client calls `POST /agents/bind`:
```bash
curl -X POST http://localhost:3001/agents/bind \
  -H "Authorization: Bearer <privy_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "agentAddress": "0x42AbCdEf01234567890123456789012345678901",
    "name": "Autonomous Treasury Agent",
    "safeAddress": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
    "guardAddress": "0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3",
    "chainId": 84532
  }'
```
Backend relayer (`0x988B225185b516DEF12A7Ec841abae9072ef4EE8`) immediately broadcasts a transaction to the live `Chapter2Guard` contract on Base Sepolia:
```solidity
// Guard contract receives the user's Privy embedded wallet
Chapter2Guard(0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3).setAutonomousAgent(PRIVY_WALLET_ADDRESS);
```

#### Step 3: Configure Spending Caps & Whitelists
Mandate limits are enforced both in the on-chain Guard and the backend deterministic policy engine:
- **Single Autonomous Limit**: 100 USDC (`100 * 1e6` = `100000000`)
- **Daily Autonomous Budget**: 500 USDC (`500 * 1e6` = `500000000`)
- **Vendor Whitelist**: `0x0000000000000000000000000000000000041c4e` (Alchemy)
- **Token Whitelist**: `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6` (Safe Native / USDC)

#### Step 4: Verify Live Mandate & Agent Registration
```bash
curl -s http://localhost:3001/mandates/active
```
Expected output:
```json
{
  "chainId": 84532,
  "safeAddress": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
  "guardAddress": "0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3",
  "autonomousAgent": "0x42AbCdEf01234567890123456789012345678901",
  "humanSigner": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
  "maxAutonomousAmountUsdc": 100.0,
  "dailyAutonomousLimitUsdc": 500.0,
  "remainingDailyBudgetUsdc": 500.0,
  "approvedRecipients": ["0x0000000000000000000000000000000000041c4e"],
  "approvedTokens": ["0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6"]
}
```

#### Step 5: Runtime Verification
1. **Under-Cap Proposal ($40)**:
   Agent proposes $40 payment -> evaluated as `ALLOW` -> executed on-chain -> `remainingDailyBudget` drops to $460.
2. **Over-Cap Proposal ($850)**:
   Agent proposes $850 renewal -> evaluated as `ESCALATE` -> push notification sent to mobile -> Ledger signs -> executed on-chain.
3. **Malicious Proposal ($5,000 to unapproved recipient)**:
   Attacker attempts unapproved destination -> evaluated as `BLOCK` -> guard contract reverts on-chain -> security alert logged.

---

## 5. Summary Matrix: Tri-Verdict Enforcement per Agent Cap

| Proposal Amount | Recipient Whitelisted? | Token Whitelisted? | Daily Cap Available? | Verdict | Action Taken | Human Review Required? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| $\le \$100$ | Yes | Yes | Yes | **`ALLOW`** | Executed autonomously via Safe | No |
| $> \$100$ | Yes | Yes | Yes | **`ESCALATE`** | EIP-712 clear-sign prompt generated; routed to mobile | **Yes (Ledger + Biometrics)** |
| Any | No | Any | Any | **`BLOCK`** | Immediate rejection; reservation freed | No (Blocked outright) |
| Any | Any | No | Any | **`BLOCK`** | Immediate rejection; reservation freed | No (Blocked outright) |
| Any | Yes | Yes | No (Exceeded) | **`ESCALATE`** | Exceeds daily budget; held for supervisor override | **Yes (Ledger + Biometrics)** |
