import Foundation

public struct WorldIdProofPayload: Equatable, Codable, Sendable {
    public let protocolVersion: String
    public let merkleRoot: String
    public let nullifierHash: String
    public let proof: String
    public let credentialType: WorldIdCredentialType
    public let action: String
    public let signal: String

    public init(
        protocolVersion: String = "4.0",
        merkleRoot: String,
        nullifierHash: String,
        proof: String,
        credentialType: WorldIdCredentialType = .credential11Selfie,
        action: String,
        signal: String
    ) {
        self.protocolVersion = protocolVersion
        self.merkleRoot = merkleRoot
        self.nullifierHash = nullifierHash
        self.proof = proof
        self.credentialType = credentialType
        self.action = action
        self.signal = signal
    }
}
