import Foundation

public enum LedgerDeviceModel: String, CaseIterable, Codable, Sendable {
    case nanoS = "Nano S"
    case nanoSP = "Nano S Plus"
    case nanoX = "Nano X"
    case stax = "Ledger Stax"
    case flex = "Ledger Flex"

    public var supportsBluetooth: Bool {
        switch self {
        case .nanoX, .stax, .flex:
            return true
        case .nanoS, .nanoSP:
            return false
        }
    }

    public var supportsTouchScreen: Bool {
        switch self {
        case .stax, .flex:
            return true
        case .nanoS, .nanoSP, .nanoX:
            return false
        }
    }

    public var screenWidthPixels: Int {
        switch self {
        case .nanoS:
            return 128
        case .nanoSP, .nanoX:
            return 128
        case .stax:
            return 400
        case .flex:
            return 480
        }
    }

    public var serviceUUIDString: String {
        switch self {
        case .nanoX:
            return "13D63400-2C97-0004-0000-4C6564676572"
        case .stax, .flex:
            return "13D63400-2C97-6004-0000-4C6564676572"
        case .nanoS, .nanoSP:
            return ""
        }
    }
}
