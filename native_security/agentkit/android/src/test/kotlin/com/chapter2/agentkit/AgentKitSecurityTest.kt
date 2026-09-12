package com.chapter2.agentkit

import com.chapter2.agentkit.biometrics.SelfieLivenessVerificationManager
import com.chapter2.agentkit.guard.AgentKitDecision
import com.chapter2.agentkit.guard.AgentKitSecurityGuard
import com.chapter2.agentkit.models.AgentKitSecurityException
import com.chapter2.agentkit.models.WorldIdCredentialType
import com.chapter2.agentkit.models.WorldIdProofPayload
import com.chapter2.agentkit.models.WorldIdSignerBinding
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class AgentKitSecurityTest {
    @Test
    fun testCredentialTypeParsing() {
        assertEquals(WorldIdCredentialType.Credential11Selfie, WorldIdCredentialType.fromString("11"))
        assertEquals(WorldIdCredentialType.Credential11Selfie, WorldIdCredentialType.fromString("selfie"))
        assertEquals(WorldIdCredentialType.Orb, WorldIdCredentialType.fromString("orb"))
        assertEquals(WorldIdCredentialType.Device, WorldIdCredentialType.fromString("device"))

        assertTrue(WorldIdCredentialType.Credential11Selfie.isBiometricVerified)
        assertTrue(WorldIdCredentialType.Orb.isBiometricVerified)
        assertFalse(WorldIdCredentialType.Device.isBiometricVerified)
    }

    @Test
    fun testValidSelfieProofValidation() {
        val manager = SelfieLivenessVerificationManager()
        val proof = WorldIdProofPayload(
            merkleRoot = "0x1234",
            nullifierHash = "0xnullifier",
            proof = "0xproofbytes",
            credentialType = WorldIdCredentialType.Credential11Selfie,
            action = "chapter2_human_verification",
            signal = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554"
        )

        val result = manager.validateSelfieProof(
            proof,
            expectedSigner = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            expectedAction = "chapter2_human_verification"
        )

        assertTrue(result.isSuccess)
    }

    @Test
    fun testRejectWeakDeviceOnlyProof() {
        val manager = SelfieLivenessVerificationManager()
        val proof = WorldIdProofPayload(
            merkleRoot = "0x1234",
            nullifierHash = "0xnullifier",
            proof = "0xproofbytes",
            credentialType = WorldIdCredentialType.Device,
            action = "chapter2_human_verification",
            signal = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554"
        )

        val result = manager.validateSelfieProof(
            proof,
            expectedSigner = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            expectedAction = "chapter2_human_verification"
        )

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is AgentKitSecurityException.WeakCredentialRejected)
    }

    @Test
    fun testRejectSignalMismatch() {
        val manager = SelfieLivenessVerificationManager()
        val proof = WorldIdProofPayload(
            merkleRoot = "0x1234",
            nullifierHash = "0xnullifier",
            proof = "0xproofbytes",
            credentialType = WorldIdCredentialType.Credential11Selfie,
            action = "chapter2_human_verification",
            signal = "0xATTACKER00000000000000000000000000000002"
        )

        val result = manager.validateSelfieProof(
            proof,
            expectedSigner = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            expectedAction = "chapter2_human_verification"
        )

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is AgentKitSecurityException.SignalMismatch)
    }

    @Test
    fun testSignerBinding90DayWindowAndTouch() {
        val now = System.currentTimeMillis()
        val binding = WorldIdSignerBinding(
            signerAddress = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            nullifierHash = "0xnullifier_001",
            credentialType = WorldIdCredentialType.Credential11Selfie,
            boundAtTimestamp = now,
            lastActiveTimestamp = now
        )

        assertTrue(binding.isValid(now))

        // Check after 45 days
        val day45 = now + (45L * 24 * 60 * 60 * 1000)
        assertTrue(binding.isValid(day45))

        // Check after 91 days (expired)
        val day91 = now + (91L * 24 * 60 * 60 * 1000)
        assertFalse(binding.isValid(day91))

        // Touch activity refreshes 90-day window
        binding.touchActivity(day45)
        assertTrue(binding.isValid(day91))
    }

    @Test
    fun testAgentKitSecurityGuardDecisions() {
        val guardService = AgentKitSecurityGuard()
        val now = System.currentTimeMillis()
        val binding = WorldIdSignerBinding(
            signerAddress = "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            nullifierHash = "0xnullifier_001",
            credentialType = WorldIdCredentialType.Credential11Selfie,
            boundAtTimestamp = now,
            lastActiveTimestamp = now
        )

        // Transfer under $100 -> ALLOW
        val allowRes = guardService.evaluateAgentAction(
            amountUnits = 50_000_000uL,
            maxAutonomousCap = 100_000_000uL,
            humanBinding = binding,
            currentTimestamp = now
        )
        assertTrue(allowRes.isSuccess)
        assertEquals(AgentKitDecision.AutonomousAllow, allowRes.getOrThrow())

        // Transfer over $100 with valid human binding -> ESCALATE
        val escalateRes = guardService.evaluateAgentAction(
            amountUnits = 250_000_000uL,
            maxAutonomousCap = 100_000_000uL,
            humanBinding = binding,
            currentTimestamp = now
        )
        assertTrue(escalateRes.isSuccess)
        assertTrue(escalateRes.getOrThrow() is AgentKitDecision.EscalateToBiometricHumanApproval)

        // Transfer over $100 without human binding -> FAIL
        val noBindingRes = guardService.evaluateAgentAction(
            amountUnits = 250_000_000uL,
            maxAutonomousCap = 100_000_000uL,
            humanBinding = null,
            currentTimestamp = now
        )
        assertTrue(noBindingRes.isFailure)
        assertTrue(noBindingRes.exceptionOrNull() is AgentKitSecurityException.AutonomousLimitExceeded)
    }
}
