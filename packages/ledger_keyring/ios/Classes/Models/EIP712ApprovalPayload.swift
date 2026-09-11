import Foundation

public struct EIP712Domain: Equatable, Codable, Sendable {
    public let name: String
    public let version: String
    public let chainId: UInt64
    public let verifyingContract: String

    public init(
        name: String = "Chapter2",
        version: String = "1",
        chainId: UInt64 = 84532,
        verifyingContract: String = "0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3"
    ) {
        self.name = name
        self.version = version
        self.chainId = chainId
        self.verifyingContract = verifyingContract
    }

    public static let baseSepoliaDefault = EIP712Domain()
}

public struct EIP712ApprovalPayload: Equatable, Codable, Sendable {
    public let actionId: String
    public let agent: String
    public let recipient: String
    public let token: String
    public let amountUnits: UInt64
    public let nonce: UInt64
    public let deadlineTimestamp: UInt64
    public let mandateHash: String
    public let riskScore: UInt8
    public let domain: EIP712Domain

    public init(
        actionId: String,
        agent: String,
        recipient: String,
        token: String,
        amountUnits: UInt64,
        nonce: UInt64,
        deadlineTimestamp: UInt64,
        mandateHash: String,
        riskScore: UInt8,
        domain: EIP712Domain = .baseSepoliaDefault
    ) {
        self.actionId = actionId
        self.agent = agent
        self.recipient = recipient
        self.token = token
        self.amountUnits = amountUnits
        self.nonce = nonce
        self.deadlineTimestamp = deadlineTimestamp
        self.mandateHash = mandateHash
        self.riskScore = riskScore
        self.domain = domain
    }

    public var formattedUsdAmount: String {
        let dollars = Double(amountUnits) / 1_000_000.0
        return String(format: "$%.2f", dollars)
    }
}
