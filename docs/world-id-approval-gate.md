# World ID + Ledger Approval Gate

## Goal
Chapter 2 escalates large agent payments to a human. Approving one should take **two independent proofs**:

1. **World ID Selfie Check:** a unique, live human is behind the approver identity.
2. **Ledger signature:** that same human physically holds the approver's Ledger key.

Neither is enough alone:
- a stolen or borrowed Ledger fails the World ID check;
- a verified human without the device can't sign.

## Status (2026-09-13)

| Piece | Status |
|---|---|
| Approval signature must recover to `LEDGER_APPROVER_ADDRESS` (`POST /x402/approvals/:id/signature` and `/reject`) | **Enforced** |
| World ID proof verification and human binding (`WorldSelfieService`: signal binding, anti-Sybil nullifiers, 90-day inactivity window; 15 tests) | **Implemented, disabled in production** (`WORLD_ID_MODE` is not `CLOUD_API`) |
| Approval requires an active World ID binding for the approver | **Not enforced** |
| App step that runs Selfie Check in World App and submits the proof | **Not built** |

**Why it's off:**
- World requires approval before an app can use Selfie Check, even in sandbox. We have requested access and are waiting.
- Enforcing the gate before that would block every escalated approval, including real Ledger tests.
- Faking verification is ruled out by the repo's zero-fallback policy.

**What that means today:** escalated payments are approved with the Ledger signature alone. The app's former onboarding step simulated a World ID proof and was removed (MOBILE-002).

## Planned design

1. **Bind the human to the Ledger (once, renewed through use).**
   - The approver completes Selfie Check in World App with `signal = LEDGER_APPROVER_ADDRESS`.
   - The app forwards the proof to the backend, together with a Ledger `personal_sign` of `chapter2-world-bind:<nullifier_hash>` that recovers to the approver address.
   - The backend verifies both and stores the binding (`human_bindings`).
   - This ties the World identity and the Ledger key to the same person.
   - Today `POST /world/selfie/bind` only binds the caller's Privy wallet, so it needs this Ledger-signature variant.
2. **Gate every approval.**
   - Before `approveWithSignature` accepts a Ledger signature, it requires `isHumanSignerVerified(LEDGER_APPROVER_ADDRESS)`.
   - On success, `touchActivity` extends the 90-day window.
   - Rejections stay ungated, because refusing a payment can't move funds.
3. **Turn it on deliberately.** Set `WORLD_ID_MODE=CLOUD_API`, `WORLD_RP_ID` and `WORLD_ACTION`, plus an explicit `REQUIRE_WORLD_ID_FOR_ESCALATIONS=true` with no default.
4. **Optional stricter mode.** Require a fresh Selfie Check for each escalation (a World action scoped to the `actionId`) instead of the 90-day binding.

## Rollout once World approves access
1. Configure the World environment variables on Render.
2. Build the app's Selfie Check step: World App handoff plus the Ledger bind signature.
3. Add the approval gate behind `REQUIRE_WORLD_ID_FOR_ESCALATIONS`.
4. Bind the approver.
5. Enable the flag.
