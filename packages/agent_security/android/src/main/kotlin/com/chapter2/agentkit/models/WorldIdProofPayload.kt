package com.chapter2.agentkit.models

public data class WorldIdProofPayload(
    val protocolVersion: String = "4.0",
    val merkleRoot: String,
    val nullifierHash: String,
    val proof: String,
    val credentialType: WorldIdCredentialType = WorldIdCredentialType.Credential11Selfie,
    val action: String,
    val signal: String
)
