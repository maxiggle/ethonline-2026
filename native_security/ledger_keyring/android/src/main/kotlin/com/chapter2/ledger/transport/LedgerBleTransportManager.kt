package com.chapter2.ledger.transport

import com.chapter2.ledger.models.LedgerDeviceModel
import com.chapter2.ledger.models.LedgerException
import com.chapter2.ledger.models.LedgerStatusWord
import java.io.ByteArrayOutputStream
import kotlin.math.min

public data class DiscoveredLedgerDevice(
    val address: String,
    val name: String,
    val model: LedgerDeviceModel,
    val rssi: Int
)

public object LedgerBleFraming {
    private const val PACKET_TYPE_APDU: Byte = 0x05

    fun frameApdu(data: ByteArray, mtu: Int): List<ByteArray> {
        if (data.isEmpty()) return emptyList()

        val packets = mutableListOf<ByteArray>()
        val totalLength = data.size
        var offset = 0
        var sequenceIndex = 0

        // Packet 0: [0x05, seq_high, seq_low, len_high, len_low, data...]
        val firstHeaderSize = 5
        val firstChunkSize = min(mtu - firstHeaderSize, data.size)
        val firstPacket = ByteArray(firstHeaderSize + firstChunkSize)
        firstPacket[0] = PACKET_TYPE_APDU
        firstPacket[1] = ((sequenceIndex shr 8) and 0xFF).toByte()
        firstPacket[2] = (sequenceIndex and 0xFF).toByte()
        firstPacket[3] = ((totalLength shr 8) and 0xFF).toByte()
        firstPacket[4] = (totalLength and 0xFF).toByte()
        System.arraycopy(data, 0, firstPacket, firstHeaderSize, firstChunkSize)
        packets.add(firstPacket)

        offset += firstChunkSize
        sequenceIndex++

        // Subsequent packets: [0x05, seq_high, seq_low, data...]
        val subHeaderSize = 3
        while (offset < data.size) {
            val chunkSize = min(mtu - subHeaderSize, data.size - offset)
            val packet = ByteArray(subHeaderSize + chunkSize)
            packet[0] = PACKET_TYPE_APDU
            packet[1] = ((sequenceIndex shr 8) and 0xFF).toByte()
            packet[2] = (sequenceIndex and 0xFF).toByte()
            System.arraycopy(data, offset, packet, subHeaderSize, chunkSize)
            packets.add(packet)

            offset += chunkSize
            sequenceIndex++
        }

        return packets
    }

    fun deframeResponse(packets: List<ByteArray>): Pair<ByteArray, LedgerStatusWord> {
        val first = packets.firstOrNull() ?: throw LedgerException.ConnectionFailed("Empty packet sequence")
        if (first.size < 5) throw LedgerException.ConnectionFailed("Malformed initial BLE packet")

        val totalLength = ((first[3].toInt() and 0xFF) shl 8) or (first[4].toInt() and 0xFF)
        val outputStream = ByteArrayOutputStream(totalLength)
        outputStream.write(first, 5, first.size - 5)

        for (packet in packets.drop(1)) {
            if (packet.size < 3) continue
            outputStream.write(packet, 3, packet.size - 3)
            if (outputStream.size() >= totalLength) break
        }

        val assembled = outputStream.toByteArray()
        if (assembled.size < 2) throw LedgerException.ConnectionFailed("Response buffer too short for status word")

        val swHigh = assembled[assembled.size - 2].toInt() and 0xFF
        val swLow = assembled[assembled.size - 1].toInt() and 0xFF
        val swCode = ((swHigh shl 8) or swLow).toUShort()
        val statusWord = LedgerStatusWord.fromCode(swCode)

        val payload = ByteArray(assembled.size - 2)
        System.arraycopy(assembled, 0, payload, 0, payload.size)

        return Pair(payload, statusWord)
    }
}
