import Foundation
import CryptoKit
import LocalAuthentication

public struct SecureEnclaveKeyInfo: Equatable, Sendable {
    public let keyTag: String
    public let publicKeyRaw: Data
    public let isStronglyHardwareIsolated: Bool

    public init(keyTag: String, publicKeyRaw: Data, isStronglyHardwareIsolated: Bool = true) {
        self.keyTag = keyTag
        self.publicKeyRaw = publicKeyRaw
        self.isStronglyHardwareIsolated = isStronglyHardwareIsolated
    }
}

public final class SecureEnclaveKeyRing: Sendable {
    public init() {}

    public static var isSecureEnclaveAvailable: Bool {
        return SecureEnclave.isAvailable
    }

    public func generateSecureEnclaveSigningKey(
        tag: String,
        requireBiometrics: Bool = true
    ) throws -> SecureEnclaveKeyInfo {
        guard SecureEnclave.isAvailable else {
            throw LedgerError.encryptionFailure(reason: "Apple Secure Enclave hardware is not available on this device.")
        }

        let accessControl: SecAccessControl?
        if requireBiometrics {
            var error: Unmanaged<CFError>?
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                [.biometryAny, .privateKeyUsage],
                &error
            )
            if let error = error?.takeRetainedValue() {
                throw LedgerError.encryptionFailure(reason: "Failed to configure biometric access control: \(error)")
            }
        } else {
            accessControl = nil
        }

        do {
            let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
                accessControl: accessControl ?? SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                    .privateKeyUsage,
                    nil
                )!
            )

            let pubKeyData = privateKey.publicKey.rawRepresentation
            return SecureEnclaveKeyInfo(
                keyTag: tag,
                publicKeyRaw: pubKeyData,
                isStronglyHardwareIsolated: true
            )
        } catch {
            throw LedgerError.encryptionFailure(reason: "Secure Enclave key generation failed: \(error.localizedDescription)")
        }
    }

    public func signWithSecureEnclave(
        digest: Data,
        using privateKey: SecureEnclave.P256.Signing.PrivateKey
    ) throws -> (signature: Data, r: Data, s: Data) {
        do {
            let signature = try privateKey.signature(for: digest)
            let derData = signature.derRepresentation
            let rawData = signature.rawRepresentation

            let r = rawData.subdata(in: 0..<32)
            let s = rawData.subdata(in: 32..<64)
            return (derData, r, s)
        } catch {
            throw LedgerError.encryptionFailure(reason: "Secure Enclave signing failed: \(error.localizedDescription)")
        }
    }

    public func deriveHardwareSharedSecret(
        ephemeralPublicKey: P256.KeyAgreement.PublicKey,
        using enclaveKey: SecureEnclave.P256.KeyAgreement.PrivateKey
    ) throws -> SymmetricKey {
        do {
            let sharedSecret = try enclaveKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
            return sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data("chapter2_enclave_salt".utf8),
                sharedInfo: Data("chapter2_lkrp_master".utf8),
                outputByteCount: 32
            )
        } catch {
            throw LedgerError.encryptionFailure(reason: "Secure Enclave key agreement failed: \(error.localizedDescription)")
        }
    }
}
