package com.chapter2.agentkit.models

public data class WorldIdSignerBinding(
    val signerAddress: String,
    val nullifierHash: String,
    val credentialType: WorldIdCredentialType,
    val boundAtTimestamp: Long = System.currentTimeMillis(),
    var lastActiveTimestamp: Long = System.currentTimeMillis(),
    var isRevoked: Boolean = false
) {
    var expiresAtTimestamp: Long = lastActiveTimestamp + SELFIE_INACTIVITY_WINDOW_MS

    fun isValid(currentTimestamp: Long = System.currentTimeMillis()): Boolean {
        if (isRevoked) return false
        return currentTimestamp < expiresAtTimestamp
    }

    fun touchActivity(currentTimestamp: Long = System.currentTimeMillis()) {
        this.lastActiveTimestamp = currentTimestamp
        this.expiresAtTimestamp = currentTimestamp + SELFIE_INACTIVITY_WINDOW_MS
    }

    companion object {
        const val SELFIE_INACTIVITY_WINDOW_MS: Long = 90L * 24 * 60 * 60 * 1000
    }
}
