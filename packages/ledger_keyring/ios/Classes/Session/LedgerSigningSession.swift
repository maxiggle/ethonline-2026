import Foundation

public struct KeyRingSignResult: Equatable, Codable, Sendable {
    public let signatureHex: String
    public let v: UInt8
    public let r: Data
    public let s: Data
    public let signerAddress: String
    public let timestamp: Date

    public init(
        signatureHex: String,
        v: UInt8,
        r: Data,
        s: Data,
        signerAddress: String,
        timestamp: Date = Date()
    ) {
        self.signatureHex = signatureHex
        self.v = v
        self.r = r
        self.s = s
        self.signerAddress = signerAddress
        self.timestamp = timestamp
    }
}

public enum SigningSessionState: Equatable, Sendable {
    case idle
    case scanning
    case connected(device: DiscoveredLedgerDevice)
    case awaitingClearSignConfirmation(prompt: LedgerClearSignPrompt)
    case completed(result: KeyRingSignResult)
    case failed(error: LedgerError)
}

public final class LedgerSigningSession: Sendable {
    public init() {}

    public func formatPrompt(
        for payload: EIP712ApprovalPayload,
        digestHex: String
    ) -> LedgerClearSignPrompt {
        let riskTier = RiskTier.from(score: payload.riskScore)

        let fields: [ClearSignField] = [
            ClearSignField(label: "Action ID", value: payload.actionId, isCritical: false),
            ClearSignField(label: "Transfer Amount", value: "\(payload.formattedUsdAmount) (\(payload.amountUnits) units)", isCritical: true),
            ClearSignField(label: "Recipient", value: payload.recipient, isCritical: true),
            ClearSignField(label: "Token Asset", value: payload.token, isCritical: false),
            ClearSignField(label: "Risk Score", value: "\(payload.riskScore) / 100 (\(riskTier.rawValue))", isCritical: true),
            ClearSignField(label: "Approval Nonce", value: "\(payload.nonce)", isCritical: false),
            ClearSignField(label: "Deadline (UTC)", value: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(payload.deadlineTimestamp))), isCritical: true),
            ClearSignField(label: "Mandate Hash", value: payload.mandateHash, isCritical: false),
        ]

        return LedgerClearSignPrompt(
            title: "CHAPTER 2 TREASURY ESCALATION",
            actionId: payload.actionId,
            fields: fields,
            digestHex: digestHex,
            riskTier: riskTier,
            timestamp: Date()
        )
    }

    public func executeMockClearSigning(
        for payload: EIP712ApprovalPayload,
        mockSigner: String,
        userApproved: Bool = true
    ) -> Result<KeyRingSignResult, LedgerError> {
        guard userApproved else {
            return .failure(.userRejectedOnDevice)
        }

        // Canonical deterministic 65-byte signature for tests
        let mockR = Data(repeating: 0x11, count: 32)
        let mockS = Data(repeating: 0x22, count: 32)
        let mockV: UInt8 = 27
        let signatureHex = "0x" + mockR.map { String(format: "%02x", $0) }.joined() +
                               mockS.map { String(format: "%02x", $0) }.joined() +
                               String(format: "%02x", mockV)

        let result = KeyRingSignResult(
            signatureHex: signatureHex,
            v: mockV,
            r: mockR,
            s: mockS,
            signerAddress: mockSigner,
            timestamp: Date()
        )
        return .success(result)
    }
}
