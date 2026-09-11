import Foundation

public struct LivenessCheckResult: Equatable, Sendable {
    public let isLivenessConfirmed: Bool
    public let confidenceScore: Double
    public let biometricTimestamp: Date

    public init(
        isLivenessConfirmed: Bool,
        confidenceScore: Double,
        biometricTimestamp: Date = Date()
    ) {
        self.isLivenessConfirmed = isLivenessConfirmed
        self.confidenceScore = confidenceScore
        self.biometricTimestamp = biometricTimestamp
    }
}

public final class SelfieLivenessCaptureCoordinator: Sendable {
    public init() {}

    public func verifyBiometricLiveness(
        confidenceScore: Double = 0.95,
        confidenceThreshold: Double = 0.85
    ) -> Result<LivenessCheckResult, AgentKitSecurityError> {
        guard confidenceScore >= confidenceThreshold else {
            return .failure(.livenessVerificationFailed(
                reason: "Confidence score \(String(format: "%.2f", confidenceScore)) below threshold \(confidenceThreshold)"
            ))
        }

        let result = LivenessCheckResult(
            isLivenessConfirmed: true,
            confidenceScore: confidenceScore,
            biometricTimestamp: Date()
        )
        return .success(result)
    }

    public func validateSelfieProof(
        proof: WorldIdProofPayload,
        expectedSigner: String,
        expectedAction: String
    ) -> Result<Void, AgentKitSecurityError> {
        guard proof.credentialType.isBiometricVerified else {
            return .failure(.weakCredentialRejected(credential: proof.credentialType))
        }

        guard proof.signal.caseInsensitiveCompare(expectedSigner) == .orderedSame else {
            return .failure(.signalMismatch(expected: expectedSigner, actual: proof.signal))
        }

        guard proof.action == expectedAction else {
            return .failure(.actionMismatch(expected: expectedAction, actual: proof.action))
        }

        return .success(())
    }
}
