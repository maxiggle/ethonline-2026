package com.chapter2.agentkit.models

public sealed class WorldIdCredentialType(
    val codeString: String,
    val isBiometricVerified: Boolean
) {
    data object Credential11Selfie : WorldIdCredentialType("11", isBiometricVerified = true)
    data object Orb : WorldIdCredentialType("orb", isBiometricVerified = true)
    data object Device : WorldIdCredentialType("device", isBiometricVerified = false)

    companion object {
        fun fromString(raw: String): WorldIdCredentialType? = when (raw.lowercase().trim()) {
            "11", "selfie" -> Credential11Selfie
            "orb" -> Orb
            "device", "0" -> Device
            else -> null
        }
    }
}
