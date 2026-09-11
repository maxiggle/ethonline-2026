import Foundation

public enum LedgerError: Error, Equatable, Sendable {
    case deviceNotFound
    case connectionFailed(reason: String)
    case disconnected
    case userRejectedOnDevice
    case deviceLocked
    case apduFailure(status: LedgerAPDUCommand.StatusWord)
    case invalidResponseLength(expected: Int, actual: Int)
    case encryptionFailure(reason: String)
    case decryptionFailure(reason: String)
    case invalidSignature
    case unsupportedDeviceModel(LedgerDeviceModel)

    public var localizedDescription: String {
        switch self {
        case .deviceNotFound:
            return "No Ledger hardware device detected within Bluetooth range."
        case .connectionFailed(let reason):
            return "Failed to establish secure connection with Ledger device: \(reason)"
        case .disconnected:
            return "Ledger hardware device disconnected unexpectedly."
        case .userRejectedOnDevice:
            return "Transaction was explicitly rejected by the human operator on the Ledger hardware screen."
        case .deviceLocked:
            return "Ledger hardware device is locked with PIN. Please unlock your device."
        case .apduFailure(let status):
            return "Hardware APDU command failed with status code: \(status)"
        case .invalidResponseLength(let expected, let actual):
            return "Received unexpected APDU byte length. Expected \(expected), got \(actual)."
        case .encryptionFailure(let reason):
            return "Hardware enclave encryption error: \(reason)"
        case .decryptionFailure(let reason):
            return "Hardware enclave decryption error: \(reason)"
        case .invalidSignature:
            return "Cryptographic signature validation failed against authorized hardware public key."
        case .unsupportedDeviceModel(let model):
            return "Device model \(model.rawValue) does not support the requested operation."
        }
    }
}
