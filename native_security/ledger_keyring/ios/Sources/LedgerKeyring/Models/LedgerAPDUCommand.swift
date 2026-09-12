import Foundation

public struct LedgerAPDUCommand: Equatable, Sendable {
    public let cla: UInt8
    public let ins: UInt8
    public let p1: UInt8
    public let p2: UInt8
    public let data: Data
    public let expectedSW: UInt16

    public init(
        cla: UInt8 = 0xE0,
        ins: UInt8,
        p1: UInt8 = 0x00,
        p2: UInt8 = 0x00,
        data: Data = Data(),
        expectedSW: UInt16 = 0x9000
    ) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.expectedSW = expectedSW
    }

    public func serialize() -> Data {
        var buffer = Data([cla, ins, p1, p2])
        if !data.isEmpty {
            buffer.append(UInt8(data.count))
            buffer.append(data)
        }
        return buffer
    }

    public enum EthereumInstruction: UInt8, Sendable {
        case getAppConfig = 0x06
        case getAddress = 0x02
        case signEIP712Message = 0x0C
        case signEIP712Domain = 0x14
        case signEIP712Struct = 0x16
    }

    public enum StatusWord: UInt16, Error, Sendable {
        case success = 0x9000
        case userRefused = 0x6985
        case securityNotSatisfied = 0x6982
        case incorrectData = 0x6A80
        case invalidP1P2 = 0x6B00
        case insNotSupported = 0x6D00
        case claNotSupported = 0x6E00
        case appNotStarted = 0x6511
        case technicalError = 0x6F00
        case unknown = 0xFFFF

        public static func from(code: UInt16) -> StatusWord {
            return StatusWord(rawValue: code) ?? .unknown
        }
    }

    public static func getAppConfiguration() -> LedgerAPDUCommand {
        return LedgerAPDUCommand(
            cla: 0xE0,
            ins: EthereumInstruction.getAppConfig.rawValue,
            p1: 0x00,
            p2: 0x00
        )
    }

    public static func signEIP712Digest(digest: Data) -> LedgerAPDUCommand {
        precondition(digest.count == 32, "EIP-712 digest must be exactly 32 bytes")
        return LedgerAPDUCommand(
            cla: 0xE0,
            ins: EthereumInstruction.signEIP712Message.rawValue,
            p1: 0x00,
            p2: 0x00,
            data: digest
        )
    }
}
