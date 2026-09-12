# Implementation Plan: Chapter 2 (Sentinel AI Guardian)

**Chapter 2** is an institutional-grade mobile command center that supervises autonomous AI agents operating a treasury.
Project Location: `/Users/godwinekainu/.gemini/antigravity-ide/scratch/chapter2`

## Execution Sequence

```
1. Contracts (Foundry)
   └── Safe Guard, EIP-712, Autonomous limits, Invariant tests
2. Backend APIs (NestJS)
   └── Asymmetric Guardian, Policy Engine, Ledger Key Ring, App Attest, World ID
3. Native Platform Packages (iOS / Android)
   └── iOS Secure Enclave & Android StrongBox biometric challenge-signers + Attestation
4. Flutter Mobile UI
   └── Very Good CLI, Flavors, BLoC state machines, High-density command center UI
```

---

## Phase 1: Smart Contracts (`contracts/`)

### Architecture
- **Framework**: Foundry (`forge`)
- **Core Contracts**:
  - `SentinelGuard.sol`: Safe Transaction Guard implementing `ITransactionGuard`.
    - Enforces on-chain recipient whitelist (`isApprovedRecipient`).
    - Enforces max autonomous per-transaction cap ($100 default).
    - Enforces 24-hour rolling daily budget ($500 default).
    - Validates EIP-712 signatures for human/Ledger-escalated transactions.
    - Emits audit events (`ActionExecuted`, `ActionBlocked`, `ActionEscalated`).
  - `ISafe.sol`: Interface for Safe wallet interactions.
  - `MockERC20.sol`: Test USDC token (6 decimals) with minting and transfers.
  - `MockSafe.sol`: Testing harness for Safe multi-sig execution.
- **Tests**:
  - `SentinelGuard.t.sol`:
    - Scenario 1: Autonomous $40 payment to approved recipient $\rightarrow$ Success.
    - Scenario 2: $850 payment attempted autonomously $\rightarrow$ Reverts with `ExceedsAutonomousLimit`.
    - Scenario 2b: $850 payment with valid EIP-712 human/Ledger signature $\rightarrow$ Success.
    - Scenario 3: $5,000 transfer to unapproved address $\rightarrow$ Reverts with `RecipientNotApproved`.
    - Invariant: Daily spending resets after 24 hours.

---

## Phase 2: Backend APIs (`backend/`)

### Architecture
- **Framework**: NestJS / TypeScript
- **Modules**:
  - `contracts/`: Ethers/Viem integration to interact with deployed `SentinelGuard` and Safe.
  - `policies/`: Deterministic policy engine with atomic balance reservation (preventing race conditions).
  - `guardian/`: Asymmetric AI Guardian engine (Deterministic hard floor + LLM anomaly detector; LLM cannot downgrade risk).
  - `ledger/`: Integration with Ledger `wallet-cli ring` for secret management and EIP-712 payload encoding.
  - `attestation/`: iOS App Attest & Android Play Integrity verification service.
  - `world/`: World ID verification & AgentBook registry lookup.
  - `actions/`: REST & WebSocket APIs for proposing, evaluating, and streaming actions to the mobile app.

---

## Phase 3: Native Platform Packages (`native_security/`)

### Architecture
- **iOS Native Module (`ios_security`)**:
  - Secure Enclave hardware key generation (`kSecAttrKeyTypeECSECPrimeRandom` on P-256).
  - Biometric access control (`kSecAccessControlBiometryCurrentSet`).
  - Cryptographic challenge signing (signs payload inside hardware without exposing private key).
  - Apple App Attest service (`DCAppAttestService`) key attestation.
- **Android Native Module (`android_security`)**:
  - Android Keystore with `KeyProperties.PURPOSE_SIGN` backed by StrongBox / TEE.
  - `BiometricPrompt` with `setUserAuthenticationRequired(true)`.
  - Challenge signing.
  - Google Play Integrity token generation.

---

## Phase 4: Flutter Mobile Command Center (`mobile/`)

### Architecture
- **Scaffolding**: Very Good CLI (`very_good create flutter_app chapter2 --org-name io.chapter2 --application-id io.chapter2.sentinel`)
- **Flavors**: `development`, `staging`, `production`
- **Layers**:
  - Domain: Entities (`Agent`, `TreasuryAction`, `GuardianDecision`, `TreasuryMandate`).
  - Infrastructure: Platform bridge to native security modules, Dio API client, WebSockets.
  - Application: `GuardianBloc`, `TreasuryBloc`, `ApprovalBloc`.
  - Presentation:
    - Screen 1: Onboarding & World ID Human Binding.
    - Screen 2: Command Center Dashboard (Treasury metrics, autonomous limits).
    - Screen 3: Agent Activity Timeline.
    - Screen 4: Guardian Alert (Risk breakdown & explanation).
    - Screen 5: EIP-712 Action Review & Hardware Biometric Gate.
    - Screen 6: Treasury Mandate Configuration.

---

## Verification Plan

### Automated Tests
1. **Contracts**: `cd contracts && forge test -vvv`
2. **Backend**: `cd backend && npm test`
3. **Mobile**: `cd mobile && flutter test && flutter analyze`

### Scenario Validation
Verify the end-to-end tri-verdict flow:
1. $40 RPC bill $\rightarrow$ ALLOW automatically.
2. $850 Infrastructure renewal $\rightarrow$ ESCALATE $\rightarrow$ Mobile biometrics $\rightarrow$ Ledger EIP-712 approval $\rightarrow$ On-chain execution.
3. $5,000 Unknown transfer $\rightarrow$ BLOCK immediately.
