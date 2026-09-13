# Chapter 2 × World

Chapter 2 lets AI agents pay for services on their own. Anything above the agent's limit needs a human to approve it on a Ledger.

**World ID answers the question the Ledger can't: is a real, unique human behind that approval?** Every big agent payment can require two independent proofs:

1. **World ID Orb verification:** a unique human stands behind the Ledger approver's address.
2. **Ledger signature:** that same human physically holds the approver's key.

A stolen or borrowed Ledger doesn't carry the binding. A verified human without the device can't sign.

Project overview: [README](../../../README.md) · Feature doc: [`docs/features/world-id-orb-ledger-approver.md`](../../features/world-id-orb-ledger-approver.md)

## What's built

### Orb verification bound to the Ledger approver
1. **Start:** in the app's **Approvals** screen, the approver taps **Verify with World ID**.
   - The backend creates the World ID request with IDKit (`@worldcoin/idkit-core` 4.2.4, `orbLegacy` preset).
   - The request's signal is the Ledger approver's address, and the request is signed with the app's RP signing key.
2. **Verify:** the approver completes the request in World App, or in World's simulator in the staging environment.
3. **Check:** the backend waits for the proof and forwards it to World's verify API (`/api/v4/verify/{rp_id}`). It accepts the proof only if:
   - World's API verifies it;
   - the credential is **Orb**;
   - the action matches;
   - the signal hash matches the Ledger approver's address;
   - this World ID isn't already bound to a different address.
4. **Bind:** the approver signs `chapter2-world-bind:<nullifier>` **on the Ledger** over Bluetooth.
   - The backend accepts it only if the signature recovers to `LEDGER_APPROVER_ADDRESS`.
   - The binding is stored for 90 days and refreshed by each approval.

Implementation:
- [`world-id-approver.service.ts`](../../../backend/src/world/world-id-approver.service.ts)
- [`world-id-approver.controller.ts`](../../../backend/src/world/world-id-approver.controller.ts)
- [`world-id-request.client.ts`](../../../backend/src/world/world-id-request.client.ts)
- [`world-id-verify.client.ts`](../../../backend/src/world/world-id-verify.client.ts)
- App: [`world_id_approver_card.dart`](../../../chapter2/lib/features/x402_approvals/view/widgets/world_id_approver_card.dart) and [`world_id_approver_cubit.dart`](../../../chapter2/lib/features/world_id/cubit/world_id_approver_cubit.dart)

### The approval gate
- **When enabled:** with `REQUIRE_WORLD_ID_FOR_ESCALATIONS=true`, the backend refuses any Ledger approval for an escalated payment (`403`) unless the approver has an active Orb binding. The app disables **Approve** until then.
- **Rejections are never gated,** because refusing a payment can't move funds.
- **Configuration:** there's no default. A partial World ID configuration stops the backend at startup instead of running without the check.

### API (all routes require a signed-in Privy user)

| Route | Purpose |
|---|---|
| `GET /world/approver/status` | Whether World ID is required and configured, and whether the Ledger approver has an active Orb binding |
| `POST /world/approver/orb-verifications` | Start an Orb verification; returns the World ID link (only to the user who started it) |
| `GET /world/approver/orb-verifications/:requestId` | Verification progress |
| `POST /world/approver/orb-verifications/:requestId/bind` | Bind the verified World ID to the Ledger approver with a Ledger signature |

### Tests
- **Backend** (Jest, no network):
  - configuration rules;
  - every proof check (wrong signal, wrong credential, wrong action, World API errors, reuse by another address);
  - binding errors (malformed or wrong signer, unknown request, not verified);
  - overlapping-poll protection;
  - the approval gate, run against the real payments service.
- **App:** models, the verification cubit, and Ledger message signing.
- **Live:** the compiled backend created a real request on World's staging service.

### Why Orb rather than Selfie Check
We first built for Selfie Check (credential 11). World restricts it: an app needs World to enable it, even for sandbox testing. We requested access and asked in the ETHOnline partner Discord channel, but nobody responded before the deadline. Orb needs no extra approval, and it's the stronger credential. The earlier Selfie Check service ([`world-selfie.service.ts`](../../../backend/src/world/world-selfie.service.ts)) stays in the repo, and the approval gate doesn't use it.

## Status
- **Deployed:** the backend is live on Render with World ID in the **staging** environment.
- **Live end-to-end test in progress:** with a remote tester's Ledger and World's simulator. The gate is switched off until the tester's Ledger is bound, then switched on.
- **Staging identities are test identities,** not real people. Production needs `WORLD_ID_ENVIRONMENT=production` and an Orb-verified approver in World App.

## Feedback for World
- **Selfie Check can't be tested without approval.** Even Sandbox requires the feature to be enabled for the app, and Sandbox app access needs a separate approval. There was no self-serve path during the hackathon, and no response to our access request.
- **Test environment docs disagree.** The integration guide says to test with `environment: "staging"` and the simulator; the Sandbox guide says `environment: sandbox`.
- **IDKit doesn't run in Node out of the box.** `IDKit.request()` loads its WASM file by calling `fetch()` on a `file:` URL, which Node's `fetch` rejects (`Failed to initialize IDKit WASM: TypeError: fetch failed`). We serve that one file from disk with a small shim ([`idkit-node-wasm-loader.ts`](../../../backend/src/world/idkit-node-wasm-loader.ts)).
