package com.chapter2.ledger.crypto

import com.chapter2.ledger.models.LedgerException
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

public data class EncryptedKeyRingPayload(
    val iv: ByteArray,
    val ciphertext: ByteArray,
    val keyName: String,
    val createdAtTimestamp: Long = System.currentTimeMillis()
) {
    val combinedSerialization: String
        get() {
            val encoder = Base64.getEncoder()
            return "${encoder.encodeToString(iv)}:${encoder.encodeToString(ciphertext)}"
        }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as EncryptedKeyRingPayload
        return iv.contentEquals(other.iv) &&
                ciphertext.contentEquals(other.ciphertext) &&
                keyName == other.keyName &&
                createdAtTimestamp == other.createdAtTimestamp
    }

    override fun hashCode(): Int {
        var result = iv.contentHashCode()
        result = 31 * result + ciphertext.contentHashCode()
        result = 31 * result + keyName.hashCode()
        result = 31 * result + createdAtTimestamp.hashCode()
        return result
    }
}

public class LedgerKeyRingProtocol {
    private val random = SecureRandom()
    private val gcmTagLengthBits = 128
    private val ivLengthBytes = 12

    fun encrypt(
        plaintext: ByteArray,
        keyName: String,
        masterKey: SecretKey
    ): EncryptedKeyRingPayload {
        try {
            val iv = ByteArray(ivLengthBytes)
            random.nextBytes(iv)

            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val parameterSpec = GCMParameterSpec(gcmTagLengthBits, iv)
            cipher.init(Cipher.ENCRYPT_MODE, masterKey, parameterSpec)

            val ciphertext = cipher.doFinal(plaintext)
            return EncryptedKeyRingPayload(
                iv = iv,
                ciphertext = ciphertext,
                keyName = keyName
            )
        } catch (e: Exception) {
            throw LedgerException.EncryptionError(e.message ?: "Encryption failure", e)
        }
    }

    fun decrypt(
        payload: EncryptedKeyRingPayload,
        masterKey: SecretKey
    ): ByteArray {
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val parameterSpec = GCMParameterSpec(gcmTagLengthBits, payload.iv)
            cipher.init(Cipher.DECRYPT_MODE, masterKey, parameterSpec)
            return cipher.doFinal(payload.ciphertext)
        } catch (e: Exception) {
            throw LedgerException.DecryptionError(e.message ?: "Decryption failure", e)
        }
    }

    companion object {
        fun deriveMasterKey(passphrase: String, salt: ByteArray): SecretKey {
            val keyFactory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
            val keySpec = PBEKeySpec(passphrase.toCharArray(), salt, 100_000, 256)
            val derivedBytes = keyFactory.generateSecret(keySpec).encoded
            return SecretKeySpec(derivedBytes, "AES")
        }
    }
}
