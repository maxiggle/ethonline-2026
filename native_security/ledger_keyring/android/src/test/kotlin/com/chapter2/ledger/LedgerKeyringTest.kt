package com.chapter2.ledger

import com.chapter2.ledger.crypto.LedgerKeyRingProtocol
import com.chapter2.ledger.models.*
import com.chapter2.ledger.session.LedgerSessionManager
import com.chapter2.ledger.transport.LedgerBleFraming
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class LedgerKeyringTest {
    @Test
    fun testDeviceModelProperties() {
        assertFalse(LedgerDeviceModel.NANO_S.supportsBle)
        assertTrue(LedgerDeviceModel.NANO_X.supportsBle)
        assertTrue(LedgerDeviceModel.STAX.supportsBle)
        assertTrue(LedgerDeviceModel.STAX.supportsTouchScreen)
        assertEquals(400, LedgerDeviceModel.STAX.screenWidthPixels)
    }

    @Test
    fun testApduCommandSerialization() {
        val digest = ByteArray(32) { 0xAB.toByte() }
        val apdu = LedgerAPDUCommand.signEip712Digest(digest)

        val bytes = apdu.serialize()
        assertEquals(4 + 1 + 32, bytes.size)
        assertEquals(0xE0.toByte(), bytes[0])
        assertEquals(LedgerAPDUCommand.INS_SIGN_EIP712_DIGEST, bytes[1])
        assertEquals(32.toByte(), bytes[4])
    }

    @Test
    fun testStatusWordDecoding() {
        assertEquals(LedgerStatusWord.Success, LedgerStatusWord.fromCode(0x9000u))
        assertEquals(LedgerStatusWord.UserRefused, LedgerStatusWord.fromCode(0x6985u))
        assertEquals(LedgerStatusWord.AppNotStarted, LedgerStatusWord.fromCode(0x6511u))
        val unknown = LedgerStatusWord.fromCode(0x1234u)
        assertTrue(unknown is LedgerStatusWord.Unknown)
        assertEquals(0x1234u.toUShort(), (unknown as LedgerStatusWord.Unknown).rawCode)
    }

    @Test
    fun testBleFramingAndDeframing() {
        val originalData = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8)
        val mtu = 10

        val packets = LedgerBleFraming.frameApdu(originalData, mtu)
        assertTrue(packets.size > 1)

        val responseBuffer = originalData + byteArrayOf(0x90.toByte(), 0x00.toByte())
        val responsePackets = LedgerBleFraming.frameApdu(responseBuffer, mtu)

        val (payload, status) = LedgerBleFraming.deframeResponse(responsePackets)
        assertArrayEquals(originalData, payload)
        assertEquals(LedgerStatusWord.Success, status)
    }

    @Test
    fun testLkrpEncryptionDecryption() {
        val protocol = LedgerKeyRingProtocol()
        val salt = ByteArray(16) { 0x42.toByte() }
        val masterKey = LedgerKeyRingProtocol.deriveMasterKey("chapter2_secure_passphrase", salt)

        val secretPlaintext = "SUPER_SECRET_AGENT_KEY".toByteArray(Charsets.UTF_8)
        val encrypted = protocol.encrypt(secretPlaintext, "agent_signer_key", masterKey)

        assertTrue(encrypted.combinedSerialization.isNotEmpty())
        assertEquals("agent_signer_key", encrypted.keyName)

        val decrypted = protocol.decrypt(encrypted, masterKey)
        assertArrayEquals(secretPlaintext, decrypted)
    }

    @Test
    fun testClearSignPromptFormatting() {
        val session = LedgerSessionManager()
        val payload = Eip712ApprovalPayload(
            actionId = "act_test_001",
            agent = "0x1111111111111111111111111111111111111111",
            recipient = "0x0000000000000000000000000000000000041c4e",
            token = "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
            amountUnits = 250_000_000uL,
            nonce = 101uL,
            deadlineTimestamp = 1800000000uL,
            mandateHash = "0x71e847c234a413ba1179ab846059c402aaefd685ad83a8b2b7161b9a95cbba84",
            riskScore = 78u
        )

        val prompt = session.formatPrompt(payload, "0xabcdef...")
        assertEquals("CHAPTER 2 TREASURY ESCALATION", prompt.title)
        assertEquals(RiskTier.HIGH_RISK, prompt.riskTier)
        assertTrue(prompt.fields.any { it.label == "Transfer Amount" && it.value.contains("$250.00") })
        assertTrue(prompt.fields.any { it.label == "Recipient" && it.value == "0x0000000000000000000000000000000000041c4e" })
    }

    @Test
    fun testMockHardwareSigning() {
        val session = LedgerSessionManager()
        val payload = Eip712ApprovalPayload(
            actionId = "act_test_002",
            agent = "0x1111111111111111111111111111111111111111",
            recipient = "0x0000000000000000000000000000000000041c4e",
            token = "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
            amountUnits = 50_000_000uL,
            nonce = 1uL,
            deadlineTimestamp = 1800000000uL,
            mandateHash = "0x1234",
            riskScore = 10u
        )

        val successRes = session.executeMockClearSigning(
            payload,
            "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            userApproved = true
        )
        assertTrue(successRes.isSuccess)
        val signResult = successRes.getOrThrow()
        assertEquals("0xA11CEAC3b97b0a701997d9145885C6A2E55b2554", signResult.signerAddress)
        assertTrue(signResult.signatureHex.startsWith("0x"))
        assertEquals(132, signResult.signatureHex.length)

        val rejectedRes = session.executeMockClearSigning(
            payload,
            "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            userApproved = false
        )
        assertTrue(rejectedRes.isFailure)
        assertTrue(rejectedRes.exceptionOrNull() is LedgerException.UserRejectedOnDevice)
    }

    @Test
    fun testStrongBoxKeyGenerationAndDescriptor() {
        val manager = com.chapter2.ledger.crypto.StrongBoxKeyStoreManager(forceStrongBoxAvailable = true)
        val config = com.chapter2.ledger.crypto.StrongBoxKeyConfig(
            keyAlias = "guardian_escrow_key_1",
            algorithm = com.chapter2.ledger.crypto.HardwareKeyAlgorithm.EC_SECP256R1,
            requireStrongBox = true,
            authRequirement = com.chapter2.ledger.crypto.BiometricAuthRequirement.BIOMETRIC_STRONG
        )

        val descriptor = manager.generateHardwareKey(config)
        assertEquals("guardian_escrow_key_1", descriptor.alias)
        assertEquals(com.chapter2.ledger.crypto.HardwareSecurityLevel.STRONGBOX, descriptor.securityLevel)
        assertTrue(descriptor.isHardwareProtected)
        assertTrue(descriptor.publicKeyBytes.isNotEmpty())

        val retrieved = manager.getKeyDescriptor("guardian_escrow_key_1")
        assertNotNull(retrieved)
        assertEquals(descriptor.alias, retrieved?.alias)
    }

    @Test
    fun testStrongBoxHardwareBiometricGatedSigning() {
        val manager = com.chapter2.ledger.crypto.StrongBoxKeyStoreManager(forceStrongBoxAvailable = true)
        val config = com.chapter2.ledger.crypto.StrongBoxKeyConfig(
            keyAlias = "guardian_auth_key",
            requireStrongBox = true,
            authRequirement = com.chapter2.ledger.crypto.BiometricAuthRequirement.BIOMETRIC_STRONG
        )
        manager.generateHardwareKey(config)

        val digest = ByteArray(32) { 0x55.toByte() }

        // Attempting to sign without biometric authentication must fail
        assertThrows(com.chapter2.ledger.crypto.StrongBoxException.BiometricAuthenticationRequired::class.java) {
            manager.signWithHardware("guardian_auth_key", digest, biometricAuthenticated = false)
        }

        // Signing with biometric authentication passes
        val signatureResult = manager.signWithHardware("guardian_auth_key", digest, biometricAuthenticated = true)
        assertEquals(com.chapter2.ledger.crypto.HardwareSecurityLevel.STRONGBOX, signatureResult.securityLevel)
        assertTrue(signatureResult.derSignature.isNotEmpty())
        assertTrue(signatureResult.r.isNotEmpty())
        assertTrue(signatureResult.s.isNotEmpty())

        // Verification passes
        val isValid = manager.verifyHardwareSignature("guardian_auth_key", digest, signatureResult.derSignature)
        assertTrue(isValid)
    }

    @Test
    fun testStrongBoxHardwareUnavailableFallback() {
        val managerNoStrongBox = com.chapter2.ledger.crypto.StrongBoxKeyStoreManager(forceStrongBoxAvailable = false)
        assertFalse(managerNoStrongBox.isStrongBoxSupported)
        assertEquals(com.chapter2.ledger.crypto.HardwareSecurityLevel.TRUSTED_ENVIRONMENT, managerNoStrongBox.currentSecurityLevel)

        // Strict StrongBox requirement fails when unavailable
        val strictConfig = com.chapter2.ledger.crypto.StrongBoxKeyConfig(
            keyAlias = "strict_key",
            requireStrongBox = true
        )
        assertThrows(com.chapter2.ledger.crypto.StrongBoxException.HardwareUnavailable::class.java) {
            managerNoStrongBox.generateHardwareKey(strictConfig)
        }

        // TEE fallback key generation succeeds
        val teeConfig = com.chapter2.ledger.crypto.StrongBoxKeyConfig(
            keyAlias = "tee_key",
            requireStrongBox = false
        )
        val descriptor = managerNoStrongBox.generateHardwareKey(teeConfig)
        assertEquals(com.chapter2.ledger.crypto.HardwareSecurityLevel.TRUSTED_ENVIRONMENT, descriptor.securityLevel)
        assertTrue(descriptor.isHardwareProtected)
    }
}

