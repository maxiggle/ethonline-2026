# Feature Documentation: World ID Credential 11 (Selfie Check Beta) Service

## 1. Overview
The **World ID Credential 11 Service** ([WorldSelfieService](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/world/world-selfie.service.ts)) integrates decentralized proof-of-personhood into the Chapter 2 AI Guardian framework. It fulfills the World ID track requirements by binding autonomous agent operators and high-risk action authorizers to a verified, living human being via **Credential 11 ("Selfie Check Beta")**.

The service provides:
1. **World ID Credential 11 (Selfie Check) Verification**:
   - Validates zero-knowledge proofs issued by World ID IDKit v4 with `credential_type: 11` (or `'selfie'`).
   - Rejects weak credentials that only prove device possession (`credential_type: 0` / `'device'`) without facial liveness.
   - Enforces cryptographic signal binding: the ZK proof signal must strictly match the operator's Ethereum address (`humanSigner`), preventing proof front-running or hijacking.
   - Validates the target `action` identifier configured for the Chapter 2 treasury deployment.
2. **Dual-Mode Verification Architecture**:
   - **Sandbox Mode** (default): Zero-dependency local verification for testing and CI/CD pipelines, validating proof structural integrity, signal fidelity, and nullifier uniqueness.
   - **Cloud API Mode**: For production environments, dispatches verification queries to World's Developer Portal API (`https://developer.worldcoin.org/api/v2/verify/{app_id}`) with API key authorization.
3. **90-Day Inactivity Window Lifecycle**:
   - Fulfills the official World ID specification for Credential 11, which mandates that selfie credentials carry a 90-day inactivity threshold (`SELFIE_INACTIVITY_WINDOW_MS = 90 * 24 * 60 * 60 * 1000`).
   - Automatically marks human bindings as expired if no supervisory activity is performed within 90 days.
   - Provides `touchActivity(signerAddress)` to refresh the lifecycle timestamp upon successful clear-signed transactions.
4. **Anti-Sybil & Anti-Replay Protection**:
   - Ensures each unique World ID `nullifier_hash` binds to at most one Ethereum signer address.
   - Prevents proof replay attacks across different signer addresses.
   - Supports manual administrative revocation via `revokeHumanBinding()`.

---

## 2. Architecture & Modules

### A. Core Interfaces (`backend/src/world/interfaces/`)
* **File**: [world-selfie.interface.ts](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/world/interfaces/world-selfie.interface.ts)
* **Exports**:
  * `WorldIdSelfieProofPayload`: Standard IDKit v4 proof structure (`merkle_root`, `nullifier_hash`, `proof`, `credential_type`, `action`, `signal`).
  * `WorldSelfieVerificationResult`: Verification verdict (`isValid`, `nullifierHash`, `credentialType`, `errorCode`, `errorMessage`, `verifiedAt`).
  * `HumanSignerBinding`: Complete human binding record linking an Ethereum address to a World ID nullifier with 90-day expiration and activity tracking.

### B. Constants (`backend/src/world/`)
* **File**: [world.constants.ts](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/world/world.constants.ts)
* **Exports**:
  * `CREDENTIAL_TYPE_SELFIE = 11`: Official World ID identifier for Selfie Check Beta.
  * `SELFIE_INACTIVITY_WINDOW_MS`: 90 days in milliseconds (7,776,000,000 ms).
  * Default app ID (`app_staging_chapter2`), action ID (`chapter2-human-operator`), and API endpoint.

### C. Service Logic (`backend/src/world/`)
* **File**: [world-selfie.service.ts](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/world/world-selfie.service.ts)
* **Methods**:
  * `verifySelfieProof(proofPayload, expectedSigner)`: Validates Credential 11 ZK proof, verifies signal binding against expected signer address, and checks action ID.
  * `bindHumanSigner(signerAddress, proofPayload)`: Verifies proof and atomically binds the nullifier to the signer address with a 90-day window, preventing Sybil duplication.
  * `isHumanSignerVerified(signerAddress)`: Returns true if the signer is bound to a verified human whose 90-day inactivity window is currently active.
  * `touchActivity(signerAddress)`: Refreshes the last active timestamp and extends the 90-day expiration window.
  * `getHumanBinding(signerAddress)`: Retrieves active binding record.
  * `revokeHumanBinding(signerAddress, reason)`: Revokes binding and frees nullifier mapping.
  * `getAllBindings()`: Enumerates all registered human bindings.

---

## 3. Test Coverage Matrix (15 / 15 Tests Passing)

| Test Suite | File | Tests Passing | Scenarios Covered |
| :--- | :--- | :--- | :--- |
| **World Selfie Service** | `world-selfie.service.spec.ts` | 15 / 15 | Service initialization & default sandbox configuration.<br>Valid Credential 11 (numeric `11`) verification.<br>Valid Credential 11 (string `'selfie'`) verification.<br>Orb-level credential verification (`'orb'`).<br>Rejection of weak device-only credential (`'device'` / `0`).<br>Rejection of mismatched action IDs.<br>Rejection of signal tampering / proof hijacking (mismatched signer address).<br>Rejection of malformed proofs (missing merkle root, nullifier, or proof bytes).<br>Successful human signer binding with 90-day expiration window.<br>Anti-Sybil replay rejection (same nullifier to different signer address).<br>Unverified / unknown signer status queries.<br>90-day inactivity expiration enforcement.<br>Activity refresh (`touchActivity`) extending the 90-day window.<br>Administrative binding revocation.<br>Active binding enumeration. |

---

## 4. Verification Commands

```bash
# Run unit tests for WorldSelfieService
cd backend && npm test -- world-selfie.service.spec.ts

# Run all backend test suites (59 tests across 6 suites)
cd backend && npm test

# Run build compilation check
cd backend && npm run build
```
