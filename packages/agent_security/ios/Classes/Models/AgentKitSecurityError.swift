import Foundation

public enum AgentKitSecurityError: Error, Equatable, Sendable {
    case weakCredentialRejected(credential: WorldIdCredentialType)
    case signalMismatch(expected: String, actual: String)
    case actionMismatch(expected: String, actual: String)
    case bindingExpired90Days(expiredAt: Date)
    case sybilNullifierReplay(nullifier: String, boundSigner: String)
    case livenessVerificationFailed(reason: String)
    case autonomousLimitExceeded(amount: UInt64, maxAutonomousCap: UInt64)

    public var localizedDescription: String {
        switch self {
        case .weakCredentialRejected(let cred):
            return "Weak device-only credential '\(cred.codeString)' rejected. World ID Credential 11 (Selfie Check Beta) facial liveness required."
        case .signalMismatch(let expected, let actual):
            return "Cryptographic signal mismatch. Expected operator address '\(expected)', got '\(actual)'. Proof hijacking detected."
        case .actionMismatch(let expected, let actual):
            return "Action mismatch. Expected '\(expected)', got '\(actual)'."
        case .bindingExpired90Days(let date):
            return "Human binding expired on \(ISO8601DateFormatter().string(from: date)) due to the 90-day inactivity window requirement."
        case .sybilNullifierReplay(let nullifier, let signer):
            return "Anti-Sybil violation: Nullifier '\(nullifier)' is already bound to another operator address '\(signer)'."
        case .livenessVerificationFailed(let reason):
            return "Facial selfie liveness verification failed: \(reason)"
        case .autonomousLimitExceeded(let amount, let cap):
            return "Action amount (\(amount) units) exceeds autonomous limit (\(cap) units). Human clear-sign escalation required."
        }
    }
}
