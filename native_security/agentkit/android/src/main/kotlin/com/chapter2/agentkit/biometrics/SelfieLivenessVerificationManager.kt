package com.chapter2.agentkit.biometrics

import com.chapter2.agentkit.models.AgentKitSecurityException
import com.chapter2.agentkit.models.WorldIdProofPayload

public data class LivenessCheckResult(
    val isLivenessConfirmed: Boolean,
    val confidenceScore: Double,
    val timestamp: Long = System.currentTimeMillis()
)

public class SelfieLivenessVerificationManager {
    fun verifyBiometricLiveness(
        confidenceScore: Double = 0.95,
        confidenceThreshold: Double = 0.85
    ): Result<LivenessCheckResult> {
        if (confidenceScore < confidenceThreshold) {
            return Result.failure(
                AgentKitSecurityException.LivenessVerificationFailed(
                    "Confidence score $confidenceScore below threshold $confidenceThreshold"
                )
            )
        }

        return Result.success(
            LivenessCheckResult(
                isLivenessConfirmed = true,
                confidenceScore = confidenceScore
            )
        )
    }

    fun validateSelfieProof(
        proof: WorldIdProofPayload,
        expectedSigner: String,
        expectedAction: String
    ): Result<Unit> {
        if (!proof.credentialType.isBiometricVerified) {
            return Result.failure(
                AgentKitSecurityException.WeakCredentialRejected(proof.credentialType)
            )
        }

        if (!proof.signal.equals(expectedSigner, ignoreCase = true)) {
            return Result.failure(
                AgentKitSecurityException.SignalMismatch(
                    expected = expectedSigner,
                    actual = proof.signal
                )
            )
        }

        if (proof.action != expectedAction) {
            return Result.failure(
                AgentKitSecurityException.ActionMismatch(
                    expected = expectedAction,
                    actual = proof.action
                )
            )
        }

        return Result.success(Unit)
    }
}
