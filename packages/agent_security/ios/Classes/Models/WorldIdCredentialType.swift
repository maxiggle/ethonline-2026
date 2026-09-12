import Foundation

public enum WorldIdCredentialType: Equatable, Hashable, Codable, Sendable {
    case credential11Selfie
    case orb
    case device

    public var codeString: String {
        switch self {
        case .credential11Selfie:
            return "11"
        case .orb:
            return "orb"
        case .device:
            return "device"
        }
    }

    public var isBiometricVerified: Bool {
        switch self {
        case .credential11Selfie, .orb:
            return true
        case .device:
            return false
        }
    }

    public static func from(raw: String) -> WorldIdCredentialType? {
        switch raw.lowercased() {
        case "11", "selfie":
            return .credential11Selfie
        case "orb":
            return .orb
        case "device", "0":
            return .device
        default:
            return nil
        }
    }
}
