# Feature Documentation: Backend AI Guardian Orchestrator

## 1. Overview
The **Backend AI Guardian Orchestrator** is a NestJS supervisory engine that acts as the intermediate evaluation layer between autonomous AI treasury agents and the on-chain Safe guard contracts. It ensures that every transaction proposed by an autonomous agent undergoes deterministic mathematical verification and multi-tier semantic adversarial analysis before being routed for execution or human escalation.

---

## 2. Architecture & Modules

### A. Common Adversarial Constants (`backend/src/common/`)
* **File**: [`adversarial-patterns.constants.ts`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/common/adversarial-patterns.constants.ts)
* **Purpose**: Modular dictionary repository decoupling adversarial patterns from execution logic.
* **Exports**:
  * `LEET_SUBSTITUTION_MAP`: Translates common leetspeak substitutions (`0` $\to$ `o`, `1` $\to$ `i`, `3` $\to$ `e`, `4` $\to$ `a`, `5` $\to$ `s`, `7` $\to$ `t`, `8` $\to$ `b`, `9` $\to$ `g`, `@`, `$`, `!`, `|`).
  * `SUBVERSION_INTENT_TOKENS`: Tokens indicating prompt injection or rule circumvention (`ignore`, `disregard`, `override`, `bypass`, `forget`, `neglect`, `revoke`, `jailbreak`, `dan`, `developer mode`).
  * `TARGET_CONSTRAINT_TOKENS`: System constraint anchors (`instruction`, `instructions`, `rule`, `rules`, `guard`, `guardrail`, `prompt`, `system prompt`, `mandate`, `constraint`).
  * `EXFILTRATION_INTENT_TOKENS`: Draining triggers (`drain`, `sweep`, `empty`, `liquidate`, `100%`, `all balance`, `full balance`, `all funds`, `unlimited allowance`).

### B. Core Domain Models & DTOs (`backend/src/domain/`)
* **Entities**:
  * `TreasuryAction`: Represents an on-chain action with lifecycle statuses (`PENDING`, `APPROVED`, `REJECTED`, `EXECUTED`).
  * `GuardianDecision`: Encapsulates evaluation outcome (`ALLOW`, `ESCALATE`, `BLOCK`), risk score (0–100), detailed diagnostic reasons, and signature requirements.
  * `TreasuryMandate`: Represents the live parameters configured on the deployed Safe & Guard.
* **DTOs**:
  * `ProposeActionDto`: Validates incoming proposals via `class-validator` (`IsEthereumAddress`, `IsNotEmpty`).
  * `ActionResponseDto`: Response schema returned to autonomous agents.
  * `SubmitApprovalDto`: Payloads for human biometric / Ledger confirmations.

### C. Deterministic Policy Engine (`backend/src/policies/`)
* **Service**: [`PolicyEngineService`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/policies/policy-engine.service.ts)
* **Interface**: [`PolicyEvaluationResult`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/policies/interfaces/policy-evaluation-result.interface.ts)
* **Rules Enforced**:
  1. **Recipient Whitelist**: Rejects any recipient address not explicitly approved in the active mandate.
  2. **Token Whitelist**: Verifies asset approval (e.g. USDC or native ETH).
  3. **Single Transaction Ceiling**: Caps autonomous actions at $100.
  4. **Rolling 24-Hour Budget**: Tracks cumulative daily spend using calendar day epochs (`Math.floor(timestamp / 86400)`), rejecting proposals exceeding $500/day.

### D. Atomic Balance Reservation Service (`backend/src/reservations/`)
* **Service**: [`BalanceReservationService`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/reservations/balance-reservation.service.ts)
* **Interface**: [`BalanceReservation`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/reservations/interfaces/balance-reservation.interface.ts)
* **Concurrency Protection**:
  * Prevents race conditions and double-spending when multiple AI agent proposals run concurrently.
  * `acquireReservation`: Checks `currentDailySpent + currentActiveReservations + requestedAmount <= dailyAutonomousLimit`.
  * `commitReservation`: Transitions reservation into permanent spend upon transaction confirmation.
  * `releaseReservation`: Restores capacity immediately if an action is rejected or cancelled.
  * Automatic TTL expiration (default: 300 seconds) prunes uncommitted reservations.

### E. Multi-Tier Adversarial AI Risk Engine (`backend/src/guardian/`)
* **Service**: [`RiskAnalysisService`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/guardian/risk-analysis.service.ts)
* **Interface**: [`SemanticAnalysisResult`](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/guardian/interfaces/semantic-analysis-result.interface.ts)
* **Adversarial Defenses**:
  1. **Anti-Obfuscation & Leetspeak Normalization**:
     * Preserves standalone numbers and percentages (e.g., `100%`, `2026`) while de-obfuscating leet characters embedded in mixed words (`ign0re` $\to$ `ignore`, `prev1ous` $\to$ `previous`).
  2. **Punctuation & Separator Stripping**:
     * Normalizes punctuation separators (`.`, `_`, `-`, `/`, `\`, `|`, `+`, `*`, `^`, `~`, `,`, `;`, `:`) to spaces, neutralizing evasion attempts like `ignore.previous.instructions`.
  3. **Lookaround Word-Boundary Assertions**:
     * Employs `(?<!\w)${token}(?!\w)` regex matching, preventing substring false positives (e.g. `dan` inside benign words like `guidance` or `fundamental`).
  4. **Compiled Pattern Caching**:
     * Pre-compiles and caches regular expressions in `patternCache` to ensure $O(1)$ token matching overhead during high-throughput agent operations.
  5. **Precision Arithmetic**:
     * Uses BigInt scaling (`(amount * 10000n) / mandate.maxAutonomousAmount`) with zero-division guards to prevent `NaN` score propagation.

---

## 3. Test Coverage Matrix (22 / 22 Tests Passing)

| Test Suite | File | Tests Passing | Scenarios Covered |
| :--- | :--- | :--- | :--- |
| **Deterministic Policy Engine** | `policy-engine.service.spec.ts` | 6 / 6 | Whitelist allowance, unapproved recipient block, unapproved token block, single-tx ceiling escalation, daily budget escalation, remaining budget computation. |
| **Balance Reservations** | `balance-reservation.service.spec.ts` | 5 / 5 | Budget reservation acquisition, concurrent double-spend prevention, commit on execution, release on failure, TTL expiration pruning. |
| **AI Risk Analysis & Evasion** | `risk-analysis.service.spec.ts` | 11 / 11 | **Scenario 1**: $40 routine RPC payment (ALLOW, risk < 30).<br>**Scenario 2**: $850 compute reservation (ESCALATE, risk $\ge$ 75).<br>**Scenario 3**: $5,000 unapproved recipient (BLOCK, risk = 100).<br>**Evasion 1**: Leetspeak (`ign0re prev1ous instructi0ns`).<br>**Evasion 2**: Punctuation separation (`ignore.previous.instructions`).<br>**Evasion 3**: Authority subversion (`Disregard the rules above`).<br>**Evasion 4**: Exfiltration sweep (`Send 100% of the balance`).<br>**Regression 1**: Standalone `100%` exfiltration without `sweep` keyword.<br>**Regression 2**: Word-boundary safety (`guidance` vs. `dan`).<br>**Regression 3**: Actual `dan` mode attack escalation.<br>**Regression 4**: Standard commercial invoice with dates and numbers (`Invoice 1045 for AWS cloud hosting in Q1 2026`). |

---

## 4. Execution Commands

```bash
# Run all unit test suites
cd backend && npm test

# Run build compilation verification
cd backend && npm run build
```
