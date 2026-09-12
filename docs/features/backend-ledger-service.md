# Feature Documentation: Backend Ledger Key Ring Service

## 1. Overview
The **Backend Ledger Key Ring Service** ([LedgerKeyRingService](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/ledger/ledger-keyring.service.ts)) acts as the final physical authority and headless secret management adapter for Chapter 2. It bridges autonomous AI treasury operations with hardware-enforced cryptographic boundaries.

The service provides:
1. **Ledger Key Ring Protocol (LKRP) Integration**:
   - Implements AES-256-GCM authenticated encryption/decryption with `scrypt` key derivation for autonomous agent operational credentials, fulfilling the ETHOnline 2026 Ledger Agent Stack track requirements.
   - CLI execution hook for Ledger's headless `wallet-cli ring`.
2. **Transparent Clear-Signing Translation**:
   - Formats raw [TreasuryActionApprovalParams](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/crypto/interfaces/eip712.interface.ts) into human-readable clear-signing prompts ([LedgerClearSignPrompt](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/ledger/interfaces/ledger-keyring.interface.ts)), displaying critical action parameters (Action ID, formatted USD amount, checksummed recipient, risk score alerts, UTC deadlines) and preventing blind signing on device screens.
3. **Escalated Action Signing & Verification**:
   - Signs typed EIP-712 approval payloads using the authorized hardware signer identity (`humanSigner`).
   - Automatically cross-verifies signatures against [Eip712Service](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/crypto/eip712.service.ts).
   - Generates ABI-encoded payloads (`abi.encode(TreasuryActionApproval, bytes sig)`) ready for Gnosis Safe execution via `Safe.execTransaction()`.
4. **Dual-Mode Architecture**:
   - Supports `MOCK_HARDWARE` (for automated CI/CD and testing with the canonical `0xA11CE` key from [Chapter2Guard.t.sol](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/contracts/test/Chapter2Guard.t.sol#L13)), `HEADLESS_CLI` (for `wallet-cli ring` daemon), and `DIRECT_TRANSPORT` (for connected devices).

---

## 2. Architecture & Modules

### A. Core Interfaces (`backend/src/ledger/interfaces/`)
* **File**: [ledger-keyring.interface.ts](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/ledger/interfaces/ledger-keyring.interface.ts)
* **Exports**:
  * `LedgerDeviceStatus`: Telemetry including connection status, mode, active signer address, and derivation path.
  * `LedgerClearSignPrompt`: Human-readable prompt layout containing tagged critical fields (`Transfer Amount`, `Recipient`, `Risk Score`, `Deadline`).
  * `KeyRingSignResult`: Signature, signer address, 32-byte digest, ABI-encoded Safe payload, and execution timestamp.
  * `KeyRingSecret`: Storage schema for AES-256-GCM encrypted agent secrets (`iv:authTag:ciphertext`).

### B. Service Logic (`backend/src/ledger/`)
* **File**: [ledger-keyring.service.ts](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/ledger/ledger-keyring.service.ts)
* **Methods**:
  * `getStatus()`: Returns active hardware mode, connected device model, and checksummed signer address.
  * `getSignerAddress()`: Resolves the authorized `humanSigner` address.
  * `formatClearSignPrompt(approval, domain)`: Formats transparent verification fields.
  * `signApproval(approval, domain)`: Generates EIP-712 signature, verifies validity, and packs Safe execution bytes.
  * `verifyLedgerSignature(approval, signature, domain)`: Direct verification check against registered hardware signer.
  * `encryptSecret(keyName, plaintext)` / `decryptSecret(secret)`: AES-256-GCM authenticated secret management with `scrypt` KDF.
  * `listKeys()`: Enumerates active keys in the key ring vault.
  * `executeCliCommand(subcommand, args)`: Spawns child process for `wallet-cli ring`.

---

## 3. Test Coverage Matrix (11 / 11 Tests Passing)

| Test Suite | File | Tests Passing | Scenarios Covered |
| :--- | :--- | :--- | :--- |
| **Ledger Key Ring Service** | `ledger-keyring.service.spec.ts` | 11 / 11 | Device status, model, derivation path, and address reporting.<br>Checksummed address verification (`0xA11CE` parity).<br>Runtime mode switching (`MOCK_HARDWARE` $\leftrightarrow$ `HEADLESS_CLI`).<br>Clear-signing prompt formatting (currency formatting, risk score, critical flags).<br>Escalated action EIP-712 signing and signature verification.<br>Safe ABI execution payload encoding and decoding.<br>Tampered payload detection.<br>AES-256-GCM secret encryption and decryption (LKRP compliance).<br>Key ring vault enumeration.<br>Tampered ciphertext / auth tag rejection. |

---

## 4. Verification Commands

```bash
# Run unit tests for LedgerKeyRingService
cd backend && npm test -- ledger-keyring.service.spec.ts

# Run all backend test suites (44 tests)
cd backend && npm test

# Run build compilation check
cd backend && npm run build
```
