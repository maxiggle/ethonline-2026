import Foundation

public enum AgentKitDecision: Equatable, Sendable {
    case autonomousAllow
    case escalateToBiometricHumanApproval(reason: String)
}

public final class AgentKitSecurityGuard: Sendable {
    public init() {}

    public func evaluateAgentAction(
        amountUnits: UInt64,
        maxAutonomousCap: UInt64 = 100_000_000,
        humanBinding: WorldIdSignerBinding?,
        currentDate: Date = Date()
    ) -> Result<AgentKitDecision, AgentKitSecurityError> {
        if amountUnits <= maxAutonomousCap {
            return .success(.autonomousAllow)
        }

        guard let binding = humanBinding else {
            return .failure(.autonomousLimitExceeded(amount: amountUnits, maxAutonomousCap: maxAutonomousCap))
        }

        guard binding.isValid(at: currentDate) else {
            return .failure(.bindingExpired90Days(expiredAt: binding.expiresAt))
        }

        return .success(.escalateToBiometricHumanApproval(
            reason: "Action exceeds autonomous ceiling (\(amountUnits) > \(maxAutonomousCap)). Verified human operator required."
        ))
    }
}
