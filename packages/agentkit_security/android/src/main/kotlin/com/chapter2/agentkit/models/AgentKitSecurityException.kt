package com.chapter2.agentkit.models

public sealed class AgentKitSecurityException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class WeakCredentialRejected(val credential: WorldIdCredentialType) :
        AgentKitSecurityException("Weak device-only credential '${credential.codeString}' rejected. World ID Credential 11 (Selfie Check Beta) facial liveness required.")

    class SignalMismatch(val expected: String, val actual: String) :
        AgentKitSecurityException("Cryptographic signal mismatch. Expected operator address '$expected', got '$actual'. Proof hijacking detected.")

    class ActionMismatch(val expected: String, val actual: String) :
        AgentKitSecurityException("Action mismatch. Expected '$expected', got '$actual'.")

    class BindingExpired90Days(val expiredAtTimestamp: Long) :
        AgentKitSecurityException("Human binding expired due to 90-day inactivity threshold.")

    class SybilNullifierReplay(val nullifier: String, val boundSigner: String) :
        AgentKitSecurityException("Anti-Sybil violation: Nullifier '$nullifier' is already bound to another operator address '$boundSigner'.")

    class LivenessVerificationFailed(val reason: String) :
        AgentKitSecurityException("Facial selfie liveness verification failed: $reason")

    class AutonomousLimitExceeded(val amount: ULong, val maxAutonomousCap: ULong) :
        AgentKitSecurityException("Action amount ($amount units) exceeds autonomous limit ($maxAutonomousCap units). Human clear-sign escalation required.")
}
