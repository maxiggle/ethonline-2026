# Mobile Scaffolding & Architecture Reference

## Overview
The **Chapter 2 Mobile Command Center** (`chapter2/`) provides an institutional supervisor interface for monitoring and authorizing autonomous AI treasury agent actions. The mobile application operates as the client layer over the on-chain Gnosis Safe guard (`Chapter2Guard.sol`), the supervisory NestJS backend, and the native hardware security layer.

## How It Was Built
1. **Scaffolding & Targets**:
   - Monorepo structure with mobile application in `chapter2/` and native plugins in root `packages/` (`packages/ledger_keyring` and `packages/agent_security`).
   - Pure mobile focus targeting **iOS** and **Android** (non-mobile targets `linux/`, `macos/`, `web/`, and `windows/` removed).
   - Application ID and bundle ID configured to `com.chapter2.app` via the `rename` package.
2. **Architecture Pattern**:
   - Built using a **Feature-First Architecture** inspired by `ai_mentor`:
     - `lib/features/<feature_name>/`: Self-contained feature slices (`dashboard/`, `timeline/`, `guardian_alert/`, `approval/`, `mandate/`, `onboarding/`) with dedicated Cubits, states, and models.
     - `lib/core/di/`: Dependency injection using `get_it` service locator (`locator.dart`).
     - `lib/services/`: REST API (`Chapter2ApiService`) and WebSocket gateway streaming (`Chapter2SocketService`).
     - `lib/shared/`: Institutional dark command center theme (`Chapter2Theme`) and core domain enums (`GuardianVerdict`).
     - `lib/app/`: Root application widget (`Chapter2App`) and `CommandCenterShell`.
3. **Hardware Plugins**:
   - `packages/ledger_keyring`: Apple Secure Enclave P-256 key generation, Android StrongBox / TEE KeyMint, BLE APDU framing, and EIP-712 signing sessions.
   - `packages/agent_security`: World ID Credential 11 (Selfie Check Beta) zero-knowledge proof parser, liveness coordination, and 90-day signer binding.

## Data Flow & Interfaces
1. **Real-Time Ingestion**:
   - `Chapter2SocketService` connects to the NestJS WebSocket gateway (`/ws`), streaming action lifecycle events (`action:proposed`, `action:escalated`, `action:executed`, `action:rejected`).
2. **Metrics & State**:
   - `DashboardCubit` computes autonomous burn rates, daily caps, and pending escalation counts from `Chapter2ApiService`.
3. **Escalated Approval Flow**:
   - `ApprovalCubit` consumes `Eip712ApprovalPayload`, validates biometric challenges through native device security, and forwards human hardware signatures to the backend for Safe execution.

## Invariants & Security
- **Domain Lexicon Discipline**: Model names and verdicts adhere strictly to `ALLOW`, `ESCALATE`, `BLOCK`, `TreasuryAction`, and `TreasuryMandate`.
- **Hardware Isolation**: High-value escalated operations (> $100 or high risk) cannot execute without an EIP-712 signature generated through hardware biometric authentication.
- **Asymmetric Trust Perimeter**: Client cannot force an `ALLOW` verdict for transactions exceeding autonomous limits without valid hardware cryptographic signatures.
