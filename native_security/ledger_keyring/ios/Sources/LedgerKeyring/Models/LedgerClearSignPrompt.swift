import Foundation

public struct ClearSignField: Equatable, Codable, Sendable {
    public let label: String
    public let value: String
    public let isCritical: Bool

    public init(label: String, value: String, isCritical: Bool = false) {
        self.label = label
        self.value = value
        self.isCritical = isCritical
    }
}

public enum RiskTier: String, Codable, Sendable {
    case benign = "BENIGN"
    case elevated = "ELEVATED"
    case highRisk = "HIGH_RISK"
    case critical = "CRITICAL"

    public static func from(score: UInt8) -> RiskTier {
        switch score {
        case 0..<50:
            return .benign
        case 50..<75:
            return .elevated
        case 75..<90:
            return .highRisk
        default:
            return .critical
        }
    }
}

public struct LedgerClearSignPrompt: Equatable, Codable, Sendable {
    public let title: String
    public let actionId: String
    public let fields: [ClearSignField]
    public let digestHex: String
    public let riskTier: RiskTier
    public let timestamp: Date

    public init(
        title: String = "CHAPTER 2 TREASURY ESCALATION",
        actionId: String,
        fields: [ClearSignField],
        digestHex: String,
        riskTier: RiskTier,
        timestamp: Date = Date()
    ) {
        self.title = title
        self.actionId = actionId
        self.fields = fields
        self.digestHex = digestHex
        self.riskTier = riskTier
        self.timestamp = timestamp
    }
}
