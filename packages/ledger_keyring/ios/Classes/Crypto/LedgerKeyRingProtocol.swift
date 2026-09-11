import Foundation
import CryptoKit

public struct EncryptedKeyRingPayload: Equatable, Codable, Sendable {
    public let nonce: Data
    public let ciphertext: Data
    public let tag: Data
    public let keyName: String
    public let createdAt: Date

    public init(
        nonce: Data,
        ciphertext: Data,
        tag: Data,
        keyName: String,
        createdAt: Date = Date()
    ) {
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
        self.keyName = keyName
        self.createdAt = createdAt
    }

    public var combinedSerialization: String {
        return "\(nonce.base64EncodedString()):\(tag.base64EncodedString()):\(ciphertext.base64EncodedString())"
    }
}

public final class LedgerKeyRingProtocol: Sendable {
    public init() {}

    public func encrypt(
        plaintext: Data,
        keyName: String,
        using masterKey: SymmetricKey
    ) throws -> EncryptedKeyRingPayload {
        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: masterKey)
            return EncryptedKeyRingPayload(
                nonce: Data(sealedBox.nonce),
                ciphertext: sealedBox.ciphertext,
                tag: sealedBox.tag,
                keyName: keyName,
                createdAt: Date()
            )
        } catch {
            throw LedgerError.encryptionFailure(reason: error.localizedDescription)
        }
    }

    public func decrypt(
        payload: EncryptedKeyRingPayload,
        using masterKey: SymmetricKey
    ) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: payload.nonce)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: payload.ciphertext,
                tag: payload.tag
            )
            return try AES.GCM.open(sealedBox, using: masterKey)
        } catch {
            throw LedgerError.decryptionFailure(reason: error.localizedDescription)
        }
    }

    public static func deriveMasterKey(from passphrase: String, salt: Data) -> SymmetricKey {
        let inputData = Data(passphrase.utf8)
        let symmetricKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: inputData),
            salt: salt,
            outputByteCount: 32
        )
        return symmetricKey
    }
}
