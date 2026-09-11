package com.chapter2.agentkit.guard

import com.chapter2.agentkit.models.AgentKitSecurityException
import com.chapter2.agentkit.models.WorldIdSignerBinding

public sealed class AgentKitDecision {
    data object AutonomousAllow : AgentKitDecision()
    data class EscalateToBiometricHumanApproval(val reason: String) : AgentKitDecision()
}

public class AgentKitSecurityGuard {
    fun evaluateAgentAction(
        amountUnits: ULong,
        maxAutonomousCap: ULong = 100_000_000uL,
        humanBinding: WorldIdSignerBinding?,
        currentTimestamp: Long = System.currentTimeMillis()
    ): Result<AgentKitDecision> {
        if (amountUnits <= maxAutonomousCap) {
            return Result.success(AgentKitDecision.AutonomousAllow)
        }

        if (humanBinding == null) {
            return Result.failure(
                AgentKitSecurityException.AutonomousLimitExceeded(
                    amount = amountUnits,
                    maxAutonomousCap = maxAutonomousCap
                )
            )
        }

        if (!humanBinding.isValid(currentTimestamp)) {
            return Result.failure(
                AgentKitSecurityException.BindingExpired90Days(
                    expiredAtTimestamp = humanBinding.expiresAtTimestamp
                )
            )
        }

        return Result.success(
            AgentKitDecision.EscalateToBiometricHumanApproval(
                "Action exceeds autonomous limit ($amountUnits > $maxAutonomousCap). Verified human operator required."
            )
        )
    }
}
