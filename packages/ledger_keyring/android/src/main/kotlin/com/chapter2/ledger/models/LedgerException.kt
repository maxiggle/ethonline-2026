package com.chapter2.ledger.models

public sealed class LedgerException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    data object DeviceNotFound : LedgerException("No Ledger hardware device detected within Bluetooth range.")
    class ConnectionFailed(val reason: String) : LedgerException("Failed to establish secure connection with Ledger device: $reason")
    data object Disconnected : LedgerException("Ledger hardware device disconnected unexpectedly.")
    data object UserRejectedOnDevice : LedgerException("Transaction was explicitly rejected by the human operator on the Ledger hardware screen.")
    data object DeviceLocked : LedgerException("Ledger hardware device is locked with PIN. Please unlock your device.")
    class ApduFailure(val status: LedgerStatusWord) : LedgerException("Hardware APDU command failed with status code: ${status.code}")
    class EncryptionError(val reason: String, cause: Throwable? = null) : LedgerException("Hardware enclave encryption error: $reason", cause)
    class DecryptionError(val reason: String, cause: Throwable? = null) : LedgerException("Hardware enclave decryption error: $reason", cause)
    data object InvalidSignature : LedgerException("Cryptographic signature validation failed against authorized hardware public key.")
}
