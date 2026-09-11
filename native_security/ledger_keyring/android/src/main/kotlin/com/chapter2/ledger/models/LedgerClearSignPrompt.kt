package com.chapter2.ledger.models

public data class ClearSignField(
    val label: String,
    val value: String,
    val isCritical: Boolean = false
)

public enum class RiskTier(val displayName: String) {
    BENIGN("BENIGN"),
    ELEVATED("ELEVATED"),
    HIGH_RISK("HIGH_RISK"),
    CRITICAL("CRITICAL");

    companion object {
        fun fromScore(score: UByte): RiskTier = when (score.toUInt()) {
            in 0u..<50u -> BENIGN
            in 50u..<75u -> ELEVATED
            in 75u..<90u -> HIGH_RISK
            else -> CRITICAL
        }
    }
}

public data class LedgerClearSignPrompt(
    val title: String = "CHAPTER 2 TREASURY ESCALATION",
    val actionId: String,
    val fields: List<ClearSignField>,
    val digestHex: String,
    val riskTier: RiskTier,
    val timestamp: Long = System.currentTimeMillis()
)
