# Chapter 2 × World

Chapter 2 lets AI agents pay for services on their own. Anything above the agent's limit needs a human to approve it on a Ledger.

**World ID answers the question the Ledger can't: is a real, unique human behind that approval?** The goal is two independent proofs for every big agent payment:

1. **World ID Selfie Check:** a unique, live human stands behind the approver identity.
2. **Ledger signature:** that same human physically holds the approver's key.

A stolen or borrowed Ledger fails the World ID check. A verified human without the device can't sign.

Project overview: [README](../../../README.md)

## What's built

### World ID verification service (backend)
[`backend/src/world/world-selfie.service.ts`](../../../backend/src/world/world-selfie.service.ts):

- **Live verification against World:** proofs are verified with World's Developer Portal verify API (v4) when `WORLD_ID_MODE=CLOUD_API`. The format-only sandbox mode is refused outside the test suite, so no proof is ever faked.
- **Strong credentials only:** a proof must be **Selfie Check (credential 11)** or **Orb**. Weaker device-only credentials are rejected.
- **Bound to the approver's wallet:** the proof's signal must equal the expected Ethereum address, so a proof can't be replayed for another signer.
- **Anti-Sybil:** a World ID nullifier can be bound to only one Ethereum address. The same human can't back multiple approver identities.
- **Lifecycle:** bindings are stored in `human_bindings`, stay valid for a 90-day inactivity window, are refreshed by approval activity, and can be revoked.

### API
[`backend/src/world/world.controller.ts`](../../../backend/src/world/world.controller.ts), all routes scoped to the signed-in Privy user:

| Route | Purpose |
|---|---|
| `POST /world/selfie/verify` | Verify a World ID proof |
| `POST /world/selfie/bind` | Bind a verified human to the signed-in wallet |
| `GET /world/selfie/status/:signerAddress` | Whether an address has an active human binding |
| `GET /world/selfie/bindings` | The caller's bindings |
| `DELETE /world/selfie/bindings/:signerAddress` | Revoke a binding |

### Tests
[`backend/src/world/world-selfie.service.spec.ts`](../../../backend/src/world/world-selfie.service.spec.ts) has 17 tests:
- accepted credentials (selfie and Orb);
- rejection of device-only credentials;
- signal tampering;
- malformed proofs;
- anti-Sybil replay;
- the 90-day expiry and activity refresh;
- revocation.

### In the app
Settings shows the signed-in wallet's World ID status from `GET /world/selfie/status/:signerAddress`. It never shows "verified" unless the backend says so.

## The approval gate: designed, not yet enforced

Full design and rollout plan: [`docs/world-id-approval-gate.md`](../../world-id-approval-gate.md)

1. **Bind:** the approver completes Selfie Check in World App with the signal set to their Ledger approver address. The binding is also signed by that Ledger, which ties the World identity and the Ledger key to the same person.
2. **Gate:** before accepting a Ledger approval for an escalated payment, the backend requires an active World ID binding for the approver address.
3. **Enable deliberately:** configure World credentials, then set `REQUIRE_WORLD_ID_FOR_ESCALATIONS=true`, which has no default.

## Status

- **Built and tested:** the verification service, binding with anti-Sybil protection and lifecycle, the API, and the app's status display.
- **Waiting on World:** Selfie Check is restricted, and World must enable it for an app, even for sandbox testing. We requested access, and it's pending.
- **Why the gate is off:** until access is granted, live verification is disabled on the deployed backend. Escalated approvals currently require the Ledger signature only. Enforcing the gate now would block every approval, and faking verification is against the project's zero-fallback rules.
