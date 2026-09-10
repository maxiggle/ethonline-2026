# Chapter 2: System Architecture & Implementation Reference

## 1. Executive Summary & Vision
**Chapter 2** is an AI Guardian mobile command center supervising autonomous AI treasury agents. It establishes an asymmetric trust perimeter combining:
- On-chain transaction guardhooks for Gnosis Safe (`Chapter2Guard.sol`).
- Deterministic policy validation with hard execution limits.
- Multi-tier adversarial NLP & semantic intent classifiers.
- Concurrency-controlled atomic balance reservations.
- Hardware-isolated EIP-712 clear-signing (Ledger Key Ring & native hardware biometrics).
- Human-backed agent verification (World ID / AgentKit).

---

## 2. Monorepo Structure

```
ethonline-2026/
├── contracts/                        # Phase 1: Smart Contracts (Foundry)
│   ├── src/
│   │   ├── Chapter2Guard.sol         # Gnosis Safe transaction guard with dual execution paths
│   │   ├── interfaces/               # Safe & Guard interfaces (ITransactionGuard, ISafe, IERC20)
│   │   └── test/MockSafe.sol         # Test harness simulating Safe execution
│   ├── script/DeployChapter2.s.sol   # Base Sepolia deployment script
│   ├── test/Chapter2Guard.t.sol      # 8/8 Foundry unit & scenario tests
│   └── deployments/base-sepolia.json # Canonical deployment records & contract addresses
├── backend/                          # Phase 2: NestJS Supervisory Backend
│   ├── src/
│   │   ├── common/                   # Shared constants & adversarial pattern dictionaries
│   │   ├── domain/                   # Core entities (TreasuryAction, GuardianDecision, TreasuryMandate) & DTOs
│   │   ├── policies/                 # Deterministic policy engine & mandate validation
│   │   ├── reservations/             # Atomic balance reservation service (anti-double-spending)
│   │   ├── guardian/                 # Asymmetric multi-tier AI risk engine & adversarial classifier
│   │   ├── crypto/                   # EIP-712 payload generator & signature verifier
│   │   ├── ledger/                   # Ledger Key Ring secret management adapter & clear-signing service
│   │   ├── world/                    # World ID Credential 11 (Selfie Check) verification & human binding
│   │   ├── app.module.ts             # Root module
│   │   └── main.ts                   # Application entry point
│   └── test/                         # End-to-end integration test suites
├── native_security/                  # Phase 3: Native Security Packages (Pending)
│   ├── ledger_keyring/               # Ledger wallet-cli ring headless secret management
│   └── agentkit/                     # World ID & AgentKit human-backed identity verification
├── chapter2/                         # Phase 4: Flutter Mobile Command Center (Pending)
└── docs/                             # Engineering specifications & feature documentation
    ├── ARCHITECTURE.md               # Master system architecture (this file)
    └── features/                     # Per-feature design specifications & guides
```

---

## 3. Canonical On-Chain Deployments

All contracts are deployed and verified on **Base Sepolia (Chain ID: `84532`)**:

| Contract | Address | Verification & Explorer |
| :--- | :--- | :--- |
| **Chapter2Guard** | `0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3` | [Blockscout Explorer](https://base-sepolia.blockscout.com/address/0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3) |
| **MockSafe** | `0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6` | [Blockscout Explorer](https://base-sepolia.blockscout.com/address/0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6) |
| **Approved Recipient (Alchemy)** | `0x0000000000000000000000000000000000041c4e` | Whitelisted operational recipient |
| **Approved Recipient (Cloudflare/IPFS)** | `0x00000000000000000000000000000000000000cf` | Whitelisted operational recipient |

### On-Chain Mandate Limits
- **Single Autonomous Cap**: $100 (`100,000,000` units at 6 decimals)
- **Rolling 24-Hour Autonomous Limit**: $500 (`500,000,000` units at 6 decimals)
- **EIP-712 Domain**:
  - `name`: `"Chapter2"`
  - `version`: `"1"`
  - `chainId`: `84532`
  - `verifyingContract`: `0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3`
- **EIP-712 Typehash**:
  `TreasuryActionApproval(string actionId,address agent,address recipient,address token,uint256 amount,uint256 nonce,uint256 deadline,bytes32 mandateHash,uint8 riskScore)`

---

## 4. The Asymmetric Trust Perimeter

```
                             [AI Treasury Agent]
                                      │
                                      ▼
                        [Propose TreasuryAction]
                                      │
                                      ▼
                   ┌──────────────────────────────────────┐
                   │   Deterministic Policy Engine        │
                   │   (Hard Mathematical Floor)          │
                   └──────────────────┬───────────────────┘
                                      │
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
        [Violates Whitelist or Caps]         [Within Base Caps & Whitelist]
                   │                                     │
                   ▼                                     ▼
         [Hard BLOCK / ESCALATE]             ┌─────────────────────────┐
                   │                         │ Multi-Tier AI Guardian  │
                   │                         │ (Adversarial Classifiers│
                   │                         └────────────┬────────────┘
                   │                                      │
                   │                    ┌─────────────────┴─────────────────┐
                   │                    ▼                                   ▼
                   │         [Semantic Evasion / Risk]           [Benign / Normal Payment]
                   │                    │                                   │
                   │                    ▼                                   ▼
                   └──────────► [Escalate to Mobile]               [Autonomous ALLOW]
                                        │                                   │
                                        ▼                                   ▼
                             [Hardware Sign / Biometrics]           [Safe On-Chain Exec]
                                        │
                                        ▼
                             [Chapter2Guard Validation]
```

### Core Invariants:
1. **The Asymmetry Rule**: The Deterministic Policy Engine provides an immutable floor. If a proposal fails deterministic constraints (e.g. unapproved recipient, single-tx > $100, daily spend > $500), the AI Guardian CANNOT downgrade the decision to `ALLOW`.
2. **Adversarial Elevation**: The AI Guardian can only elevate risk from `ALLOW` to `ESCALATE`.
3. **Cryptographic Proofs Over Tokens**: High-value transactions cannot execute without an EIP-712 signature matching the authorized `humanSigner` hardware key.

---

## 5. Branching & PR Discipline

To ensure strict code quality, authentic commit telemetry, and conflict-free feature development:
1. **Branch Segmentation**:
   - `main`: Production-ready, deployed milestones.
   - `development`: Primary integration branch.
   - `feature/<micro-feature>`: Isolated branch for each individual sub-module.
2. **Review & Merge Flow**:
   - All feature work occurs on dedicated micro-feature branches cut from `development`.
   - Before opening a PR: all unit tests must pass (`npm test` / `forge test`) and builds must succeed (`npm run build`).
   - PR is opened against `development` using GitHub CLI (`gh pr create`).
   - PR is merged into `development` and local `development` is synchronized before cutting the next micro-feature.
3. **Commit Quality Rules**:
   - Never use blanket staging (`git add .`).
   - Stage exact relative filepaths (`git add path/to/file.ts`).
   - Commit messages adhere to conventional commit standards (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`).
   - Zero decorative banner comments or trailing inline annotations.
