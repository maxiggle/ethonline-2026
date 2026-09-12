# Feature Documentation: Chapter2Guard Smart Contracts

## Overview
**Chapter2Guard** is an on-chain transaction guard designed for Gnosis Safe accounts operating autonomous AI treasuries. It enforces on-chain boundaries between an AI agent's proposals and actual fund movement:
1. Routine operational payments within a defined threshold ($100 per transaction, $500 daily budget) to pre-approved recipients are executed autonomously without human friction.
2. Suspicious or high-value transactions automatically revert unless accompanied by an authorized human signature generated through a hardware-backed device (such as Ledger) using typed EIP-712 clear-signing.
3. Dangerous payments to unapproved addresses are blocked on-chain, preventing compromised AI agents or backends from draining treasury assets.

---

## How It Was Built
- **Base Architecture**: Gnosis Safe `ITransactionGuard` hook pattern.
- **Contract Components**:
  - `Chapter2Guard.sol`: The core transaction guard attached to the Safe via `safe.setGuard(address(guard))`.
  - `ITransactionGuard.sol`: Interface exposing `checkTransaction` and `checkAfterExecution`.
  - `ISafe.sol`: Interface for Safe wallet interactions.
  - `IERC20.sol`: Interface for ERC-20 asset transfers.
  - `MockSafe.sol`: Test harness simulating Safe execution.
  - `DeployChapter2.s.sol`: Deployment automation script for testnets.
- **EIP-712 Implementation**:
  - Domain: `name="Chapter2"`, `version="1"`, `chainId=block.chainid`, `verifyingContract=address(this)`.
  - Typehash: `TreasuryActionApproval(string actionId,address agent,address recipient,address token,uint256 amount,uint256 nonce,uint256 deadline,bytes32 mandateHash,uint8 riskScore)`.
  - Cryptographic validation via `ecrecover` matching `humanSigner` (Ledger hardware key).

---

## Data Flow & Interfaces

```
AI Treasury Agent / Relayer
            │
            ▼
    Safe.execTransaction(...)
            │
            ▼
  Chapter2Guard.checkTransaction(...)
            │
            ├── Is msgSender == owner? ─────────────────────────► [ALLOW DIRECT]
            │
            ├── Is recipient whitelisted in isApprovedRecipient?
            │     └── NO ──────────────────────────────────────► [REVERT: RecipientNotApproved]
            │
            ├── Is msgSender == autonomousAgent?
            │     ├── Amount <= $100 AND DailySpent + Amount <= $500?
            │     │     └── YES ───────────────────────────────► [ALLOW AUTONOMOUS]
            │     │
            │     └── Amount > $100 (Escalated Action)?
            │           ├── Signatures present?
            │           │     ├── Valid EIP-712 human signature & unused nonce?
            │           │     │     └── YES ───────────────────► [ALLOW ESCALATED]
            │           │     └── NO ──────────────────────────► [REVERT: InvalidSignature / NonceAlreadyUsed]
            │           └── NO Signatures ─────────────────────► [REVERT: ExceedsAutonomousLimit]
            │
            └── Safe executes transfer to recipient
```

---

## Trade-offs & Security Invariants Handled

1. **Replay Attack Prevention**:
   - Every escalated approval contains a unique `uint256 nonce` and `uint256 deadline`.
   - Once executed, `usedActionNonces[nonce]` is permanently set to `true`. Re-submitting the same payload immediately reverts with `NonceAlreadyUsed`.
2. **Asymmetric AI Protection**:
   - The smart contract does not depend on backend or LLM inputs for safety. If an agent attempts to execute an unapproved transfer or breach limits, the transaction fails at the EVM level regardless of any prompt injection or backend breach.
3. **Rolling Daily Budget Isolation**:
   - Daily spending is tracked using `dailySpent[block.timestamp / 1 days]`.
   - Once a calendar day transitions, the spending ceiling automatically resets to the configured allowance without requiring manual administrative calls.
4. **Owner Direct Bypass**:
   - The human owner can interact directly through the Safe to manage emergency situations or treasury allocations without being constrained by the autonomous agent caps.
5. **Dynamic Autonomous Agent Registration & Hardware Separation**:
   - The contract supports `setAutonomousAgent(address _agent) external onlyOwner`.
   - Each registered user's **Privy Embedded EVM Wallet** (`user.walletAddress`) is bound dynamically as the on-chain `autonomousAgent`.
   - Routine disbursements operate autonomously under the user's Privy key within pre-configured mandate limits ($100/tx, $500/day).
   - High-value disbursements and limit overrides strictly require typed EIP-712 clear-signing from the user's **Ledger hardware wallet** (`humanSigner`), ensuring hardware-enforced cold governance.
