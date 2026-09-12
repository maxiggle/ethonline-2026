package com.chapter2.ledger.session

import com.chapter2.ledger.models.*
import java.time.Instant
import java.time.format.DateTimeFormatter

public data class KeyRingSignResult(
    val signatureHex: String,
    val v: Byte,
    val r: ByteArray,
    val s: ByteArray,
    val signerAddress: String,
    val timestamp: Long = System.currentTimeMillis()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as KeyRingSignResult
        return signatureHex == other.signatureHex &&
                v == other.v &&
                r.contentEquals(other.r) &&
                s.contentEquals(other.s) &&
                signerAddress == other.signerAddress &&
                timestamp == other.timestamp
    }

    override fun hashCode(): Int {
        var result = signatureHex.hashCode()
        result = 31 * result + v.toInt()
        result = 31 * result + r.contentHashCode()
        result = 31 * result + s.contentHashCode()
        result = 31 * result + signerAddress.hashCode()
        result = 31 * result + timestamp.hashCode()
        return result
    }
}

public class LedgerSessionManager {
    fun formatPrompt(
        payload: Eip712ApprovalPayload,
        digestHex: String
    ): LedgerClearSignPrompt {
        val riskTier = RiskTier.fromScore(payload.riskScore)

        val deadlineIso = DateTimeFormatter.ISO_INSTANT.format(
            Instant.ofEpochSecond(payload.deadlineTimestamp.toLong())
        )

        val fields = listOf(
            ClearSignField(label = "Action ID", value = payload.actionId, isCritical = false),
            ClearSignField(label = "Transfer Amount", value = "${payload.formattedUsdAmount} (${payload.amountUnits} units)", isCritical = true),
            ClearSignField(label = "Recipient", value = payload.recipient, isCritical = true),
            ClearSignField(label = "Token Asset", value = payload.token, isCritical = false),
            ClearSignField(label = "Risk Score", value = "${payload.riskScore} / 100 (${riskTier.displayName})", isCritical = true),
            ClearSignField(label = "Approval Nonce", value = payload.nonce.toString(), isCritical = false),
            ClearSignField(label = "Deadline (UTC)", value = deadlineIso, isCritical = true),
            ClearSignField(label = "Mandate Hash", value = payload.mandateHash, isCritical = false)
        )

        return LedgerClearSignPrompt(
            title = "CHAPTER 2 TREASURY ESCALATION",
            actionId = payload.actionId,
            fields = fields,
            digestHex = digestHex,
            riskTier = riskTier
        )
    }

    fun executeMockClearSigning(
        payload: Eip712ApprovalPayload,
        mockSigner: String,
        userApproved: Boolean = true
    ): Result<KeyRingSignResult> {
        if (!userApproved) {
            return Result.failure(LedgerException.UserRejectedOnDevice)
        }

        val mockR = ByteArray(32) { 0x11.toByte() }
        val mockS = ByteArray(32) { 0x22.toByte() }
        val mockV: Byte = 27

        val rHex = mockR.joinToString("") { String.format("%02x", it) }
        val sHex = mockS.joinToString("") { String.format("%02x", it) }
        val vHex = String.format("%02x", mockV)
        val signatureHex = "0x$rHex$sHex$vHex"

        val result = KeyRingSignResult(
            signatureHex = signatureHex,
            v = mockV,
            r = mockR,
            s = mockS,
            signerAddress = mockSigner
        )
        return Result.success(result)
    }
}
