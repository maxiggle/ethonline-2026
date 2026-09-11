import Foundation

public struct WorldIdSignerBinding: Equatable, Codable, Sendable {
    public static let selfieInactivityWindowSeconds: TimeInterval = 90 * 24 * 3600

    public let signerAddress: String
    public let nullifierHash: String
    public let credentialType: WorldIdCredentialType
    public let boundAt: Date
    public var lastActiveAt: Date
    public var expiresAt: Date
    public var isRevoked: Bool

    public init(
        signerAddress: String,
        nullifierHash: String,
        credentialType: WorldIdCredentialType,
        boundAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isRevoked: Bool = false
    ) {
        self.signerAddress = signerAddress
        self.nullifierHash = nullifierHash
        self.credentialType = credentialType
        self.boundAt = boundAt
        self.lastActiveAt = lastActiveAt
        self.expiresAt = lastActiveAt.addingTimeInterval(Self.selfieInactivityWindowSeconds)
        self.isRevoked = isRevoked
    }

    public func isValid(at currentDate: Date = Date()) -> Bool {
        guard !isRevoked else { return false }
        return currentDate < expiresAt
    }

    public mutating func touchActivity(at currentDate: Date = Date()) {
        self.lastActiveAt = currentDate
        self.expiresAt = currentDate.addingTimeInterval(Self.selfieInactivityWindowSeconds)
    }
}
