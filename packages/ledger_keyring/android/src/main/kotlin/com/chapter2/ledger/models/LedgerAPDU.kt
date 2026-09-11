package com.chapter2.ledger.models

public data class LedgerAPDUCommand(
    val cla: Byte = 0xE0.toByte(),
    val ins: Byte,
    val p1: Byte = 0x00.toByte(),
    val p2: Byte = 0x00.toByte(),
    val data: ByteArray = ByteArray(0),
    val expectedSw: UShort = 0x9000u
) {
    public fun serialize(): ByteArray {
        val hasData = data.isNotEmpty()
        val totalSize = 4 + (if (hasData) 1 + data.size else 0)
        val buffer = ByteArray(totalSize)

        buffer[0] = cla
        buffer[1] = ins
        buffer[2] = p1
        buffer[3] = p2

        if (hasData) {
            buffer[4] = data.size.toByte()
            System.arraycopy(data, 0, buffer, 5, data.size)
        }

        return buffer
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as LedgerAPDUCommand
        return cla == other.cla &&
                ins == other.ins &&
                p1 == other.p1 &&
                p2 == other.p2 &&
                data.contentEquals(other.data) &&
                expectedSw == other.expectedSw
    }

    override fun hashCode(): Int {
        var result = cla.toInt()
        result = 31 * result + ins.toInt()
        result = 31 * result + p1.toInt()
        result = 31 * result + p2.toInt()
        result = 31 * result + data.contentHashCode()
        result = 31 * result + expectedSw.hashCode()
        return result
    }

    companion object {
        const val INS_GET_APP_CONFIG: Byte = 0x06
        const val INS_GET_ADDRESS: Byte = 0x02
        const val INS_SIGN_EIP712_DIGEST: Byte = 0x0C

        fun signEip712Digest(digest: ByteArray): LedgerAPDUCommand {
            require(digest.size == 32) { "EIP-712 digest must be exactly 32 bytes" }
            return LedgerAPDUCommand(
                cla = 0xE0.toByte(),
                ins = INS_SIGN_EIP712_DIGEST,
                p1 = 0x00,
                p2 = 0x00,
                data = digest
            )
        }
    }
}

public sealed class LedgerStatusWord(val code: UShort) {
    data object Success : LedgerStatusWord(0x9000u)
    data object UserRefused : LedgerStatusWord(0x6985u)
    data object SecurityNotSatisfied : LedgerStatusWord(0x6982u)
    data object IncorrectData : LedgerStatusWord(0x6A80u)
    data object InvalidP1P2 : LedgerStatusWord(0x6B00u)
    data object InsNotSupported : LedgerStatusWord(0x6D00u)
    data object ClaNotSupported : LedgerStatusWord(0x6E00u)
    data object AppNotStarted : LedgerStatusWord(0x6511u)
    data object TechnicalError : LedgerStatusWord(0x6F00u)
    data class Unknown(val rawCode: UShort) : LedgerStatusWord(rawCode)

    companion object {
        fun fromCode(code: UShort): LedgerStatusWord = when (code) {
            0x9000u.toUShort() -> Success
            0x6985u.toUShort() -> UserRefused
            0x6982u.toUShort() -> SecurityNotSatisfied
            0x6A80u.toUShort() -> IncorrectData
            0x6B00u.toUShort() -> InvalidP1P2
            0x6D00u.toUShort() -> InsNotSupported
            0x6E00u.toUShort() -> ClaNotSupported
            0x6511u.toUShort() -> AppNotStarted
            0x6F00u.toUShort() -> TechnicalError
            else -> Unknown(code)
        }
    }
}
