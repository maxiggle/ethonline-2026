package com.chapter2.ledger.models

public data class Eip712Domain(
    val name: String = "Chapter2",
    val version: String = "1",
    val chainId: Long = 84532L,
    val verifyingContract: String = "0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3"
) {
    companion object {
        val BASE_SEPOLIA_DEFAULT = Eip712Domain()
    }
}

public data class Eip712ApprovalPayload(
    val actionId: String,
    val agent: String,
    val recipient: String,
    val token: String,
    val amountUnits: ULong,
    val nonce: ULong,
    val deadlineTimestamp: ULong,
    val mandateHash: String,
    val riskScore: UByte,
    val domain: Eip712Domain = Eip712Domain.BASE_SEPOLIA_DEFAULT
) {
    val formattedUsdAmount: String
        get() {
            val dollars = amountUnits.toDouble() / 1_000_000.0
            return String.format("$%.2f", dollars)
        }
}
