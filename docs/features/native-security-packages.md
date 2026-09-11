# Native Security Packages: Hardware Key Rings & AgentKit Identity

## 1. Overview
The `native_security/` module provides strongly-typed, hardware-isolated mobile bridges for iOS (Swift 6) and Android (Kotlin) in the Chapter 2 Guardian Mobile Command Center. It enforces hardware security boundaries to supervise autonomous AI treasury agents without relying on untyped dictionaries, generic object wrappers, or software-only private key storage.

---

## 2. Architecture & Hardware Security Boundaries

### 2.1 Apple Secure Enclave (iOS)
- **Hardware Isolation**: Built on Apple's Secure Enclave Processor (SEP) using `CryptoKit.SecureEnclave`. Keys are generated directly on-die and **never leave physical silicon or enter application RAM**.
- **Biometric Hardware Gating**: Hardware signing is gated by `SecAccessControlCreateWithFlags` requiring `[.biometryAny, .privateKeyUsage]` (Face ID / Touch ID).
- **Session Protection (LKRP)**: Hardware-derived ECDH shared secret derivation (`hkdfDerivedSymmetricKey`) wraps Ledger session keys and agent signing credentials.

### 2.2 Android StrongBox Keymaster / KeyMint (Android)
- **Hardware Isolation**: Dedicated discrete Hardware Security Module (HSM) chip (e.g., Google Titan M/M2 on Pixel, Samsung Knox Vault) configured with `setIsStrongBoxBacked(true)`.
- **Hardware Gating**: Configured with `.setUserAuthenticationRequired(true)` for hardware-enforced `BiometricPrompt` per-operation authentication.
- **Graceful TEE Fallback**: If an Android device lacks discrete StrongBox hardware, it safely operates inside ARM TrustZone (`SecurityLevel.TRUSTED_ENVIRONMENT`) rather than degrading to insecure software storage.

---

## 3. Package Structure

### 3.1 `native_security/ledger_keyring`
Hardware clear-signing, APDU protocol framing, Bluetooth Low Energy (BLE) packet chunking, and Ledger Key Ring Protocol (LKRP) secret wrapping.

#### iOS (`native_security/ledger_keyring/ios/`)
- `Package.swift`: Swift 6 package targeting iOS 16+ and macOS 13+.
- `Models/LedgerDeviceModel.swift`: Exhaustive enum (`nanoS`, `nanoSP`, `nanoX`, `stax`, `flex`) with screen dimensions and BLE service UUIDs (`13D63400-2C97-0004-0000-4C6564676572`).
- `Models/LedgerAPDUCommand.swift`: Strongly-typed APDU command framing (`signEIP712Digest`, `getAppConfiguration`, `getAddress`) and ISO 7816 `StatusWord` enum.
- `Models/LedgerClearSignPrompt.swift`: Strongly-typed clear-sign prompt layout, field value formatting, and `RiskTier`.
- `Models/EIP712ApprovalPayload.swift`: Strongly-typed domain and message payload matching `Chapter2Guard.sol`.
- `Crypto/LedgerKeyRingProtocol.swift`: AES-256-GCM authenticated encryption with PBKDF2 master key derivation.
- `Crypto/SecureEnclaveKeyRing.swift`: Apple Secure Enclave hardware key generation and Face ID / Touch ID hardware signing.
- `Transport/LedgerBLEManager.swift`: BLE MTU chunking and packet reassembly conforming to the Ledger BLE Framing Specification.
- `Session/LedgerSigningSession.swift`: High-level clear-signing session controller.

#### Android (`native_security/ledger_keyring/android/`)
- `build.gradle.kts`: Kotlin JVM Gradle configuration.
- `models/LedgerDeviceModel.kt`: Strongly-typed device models.
- `models/LedgerAPDU.kt`: APDU framing and sealed class `LedgerStatusWord`.
- `models/LedgerClearSignPrompt.kt`: Strongly-typed clear-sign prompt data classes.
- `models/Eip712ApprovalPayload.kt`: Canonical EIP-712 payload matching on-chain contracts.
- `crypto/LedgerKeyRingProtocol.kt`: AES-256-GCM encryption with PBKDF2 master key derivation.
- `crypto/StrongBoxKeyStore.kt`: Strongly-typed Android StrongBox Keymaster/KeyMint hardware key manager with biometric gating and TEE fallback.
- `transport/LedgerBleTransportManager.kt`: BLE MTU packet chunking and response reassembly.
- `session/LedgerSessionManager.kt`: Session manager for hardware clear-signing.

---

### 3.2 `native_security/agentkit`
World ID Credential 11 (Selfie Check Beta) zero-knowledge proof verification, facial liveness capture, and 90-day inactivity lifecycle binding for autonomous agents.

#### iOS (`native_security/agentkit/ios/`)
- `Package.swift`: Swift 6 package targeting iOS 16+ and macOS 13+.
- `Models/WorldIdCredentialType.swift`: Exhaustive enum (`credential11Selfie`, `orb`, `device`).
- `Models/WorldIdProofPayload.swift`: IDKit v4 ZK-proof struct (`nullifierHash`, `merkleRoot`, `proof`, `credentialType`).
- `Models/WorldIdSignerBinding.swift`: 90-day inactivity lifecycle tracking and heartbeat validation.
- `Models/AgentKitSecurityError.swift`: Strongly-typed domain error hierarchy.
- `Biometrics/SelfieLivenessCaptureCoordinator.swift`: Front camera facial liveness capture and biometric signal generation.
- `Guard/AgentKitSecurityGuard.swift`: AgentKit action supervisor validating human verification state before allowing high-risk autonomous transactions.

#### Android (`native_security/agentkit/android/`)
- `build.gradle.kts`: Kotlin JVM Gradle configuration.
- `models/WorldIdCredentialType.kt`: Sealed class hierarchy (`Credential11Selfie`, `Orb`, `Device`).
- `models/WorldIdProofPayload.kt`: Strongly-typed ZK-proof data class.
- `models/WorldIdSignerBinding.kt`: 90-day lifecycle tracker.
- `models/AgentKitSecurityException.kt`: Sealed exception hierarchy.
- `biometrics/SelfieLivenessVerificationManager.kt`: Biometric liveness capture coordinator.
- `guard/AgentKitSecurityGuard.kt`: Action security supervisor.

---

## 4. Strict Strong-Typing Guarantees
In compliance with institutional security requirements:
- **Zero Generic Dictionaries**: No `[String: Any]` in Swift or `Map<String, Any>` in Kotlin.
- **Pure Value Semantics**: All models use immutable structs / data classes with explicit types (`UInt64`, `Data`, `UShort`, `ByteArray`, `ULong`).
- **Sealed Error Hierarchies**: All error states are modeled as exhaustive Swift enums or Kotlin sealed classes to force compile-time pattern matching.
