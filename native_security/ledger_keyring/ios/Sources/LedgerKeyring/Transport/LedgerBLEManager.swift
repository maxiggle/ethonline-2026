import Foundation

public struct DiscoveredLedgerDevice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let model: LedgerDeviceModel
    public let rssi: Int

    public init(id: UUID, name: String, model: LedgerDeviceModel, rssi: Int) {
        self.id = id
        self.name = name
        self.model = model
        self.rssi = rssi
    }
}

public final class LedgerBLEFraming: Sendable {
    private static let packetTypeAPDU: UInt8 = 0x05

    public init() {}

    public static func frameAPDU(data: Data, mtu: Int) -> [Data] {
        guard !data.isEmpty else { return [] }

        var packets: [Data] = []
        let totalLength = UInt16(data.count)
        var offset = 0
        var sequenceIndex: UInt16 = 0

        // First packet: [0x05, seq_high, seq_low, len_high, len_low, payload...]
        let firstHeaderSize = 5
        let firstChunkSize = min(mtu - firstHeaderSize, data.count)
        var firstPacket = Data([
            packetTypeAPDU,
            UInt8((sequenceIndex >> 8) & 0xFF),
            UInt8(sequenceIndex & 0xFF),
            UInt8((totalLength >> 8) & 0xFF),
            UInt8(totalLength & 0xFF)
        ])
        firstPacket.append(data.subdata(in: 0..<firstChunkSize))
        packets.append(firstPacket)
        offset += firstChunkSize
        sequenceIndex += 1

        // Subsequent packets: [0x05, seq_high, seq_low, payload...]
        let subHeaderSize = 3
        while offset < data.count {
            let chunkSize = min(mtu - subHeaderSize, data.count - offset)
            var packet = Data([
                packetTypeAPDU,
                UInt8((sequenceIndex >> 8) & 0xFF),
                UInt8(sequenceIndex & 0xFF)
            ])
            packet.append(data.subdata(in: offset..<(offset + chunkSize)))
            packets.append(packet)
            offset += chunkSize
            sequenceIndex += 1
        }

        return packets
    }

    public static func deframeResponse(packets: [Data]) throws -> (payload: Data, status: LedgerAPDUCommand.StatusWord) {
        guard let first = packets.first, first.count >= 5 else {
            throw LedgerError.invalidResponseLength(expected: 5, actual: packets.first?.count ?? 0)
        }

        let totalLength = Int((UInt16(first[3]) << 8) | UInt16(first[4]))
        var assembled = Data(first.subdata(in: 5..<first.count))

        for packet in packets.dropFirst() {
            guard packet.count >= 3 else { continue }
            assembled.append(packet.subdata(in: 3..<packet.count))
            if assembled.count >= totalLength {
                break
            }
        }

        guard assembled.count >= 2 else {
            throw LedgerError.invalidResponseLength(expected: 2, actual: assembled.count)
        }

        let swHigh = UInt16(assembled[assembled.count - 2])
        let swLow = UInt16(assembled[assembled.count - 1])
        let swCode = (swHigh << 8) | swLow
        let status = LedgerAPDUCommand.StatusWord.from(code: swCode)

        let responsePayload = assembled.subdata(in: 0..<(assembled.count - 2))
        return (responsePayload, status)
    }
}
