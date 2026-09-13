# TICKET MOBILE-004: World ID Orb Verification for the Ledger Approver (Android APK)

**Time box:** 3 h · **Component:** `chapter2/` (Flutter, Android) · **Depends on:** the API contract in [WORLD-001](TICKET-WORLD-001-ORB-VERIFIED-LEDGER-APPROVER.md) (build against it now; the backend lands in parallel) and MOBILE-001 (done) · **Read first:** `docs/tickets/README.md`, then the "API contract" section of WORLD-001

## Why
- **The goal:** before the backend accepts a Ledger approval, the approver must be a World ID **Orb**-verified human, bound to that same Ledger.
- **Who tests:** a remote tester with the Ledger and an APK.
- **The app flow:**
  1. Start an Orb verification.
  2. Complete it in the World ID **simulator** (staging) or World App (production).
  3. Sign a binding message on the connected Ledger over Bluetooth.
  4. After that, approvals work while the backend requires World ID.

**Out of scope:**
- **Backend changes:** WORLD-001 handles them.
- **Legacy code:** the old onboarding World ID step and `/world/selfie/*` stay unused.
- **iOS:** no iOS-specific work beyond compiling.

## Backend contract (from WORLD-001; all routes need the Privy bearer token, which the shared `ApiClient` already sends after login)

| Call | Response |
|---|---|
| `GET /world/approver/status` | `{ approverAddress, isWorldIdRequired, isWorldIdConfigured, environment: 'staging'\|'production'\|null, isVerified, credential: 'orb'\|null, boundAt, expiresAt }` |
| `POST /world/approver/orb-verifications` | `201 { requestId, status, connectorUrl, expiresAt, bindMessage, errorMessage }`; `503` if unconfigured |
| `GET /world/approver/orb-verifications/:requestId` | same shape; `404` if unknown |
| `POST /world/approver/orb-verifications/:requestId/bind` body `{ signature }` | `200` status object; `401` wrong signer; `409` not `VERIFIED` or expired |

- **`status` values:** `WAITING_FOR_WORLD_APP | AWAITING_CONFIRMATION | VERIFIED | BOUND | FAILED | EXPIRED`.
- **`connectorUrl`:** present only while waiting or awaiting.
- **`bindMessage`:** `chapter2-world-bind:<nullifier>`, present only when `VERIFIED`.
- **Existing route:** `POST /x402/approvals/:id/signature` now returns `403` when World ID is required and the approver isn't bound.
- **Secret link:** `connectorUrl` contains a secret key. Never log or print it (no `debugPrint`/`log`).

## Implementation
Follow the existing patterns in `lib/features/x402_approvals/` (api service over `ApiClient`, Cubit and Equatable state, fakes in tests).

1. **Models** (`lib/features/world_id/remote/models/`):
   - `WorldIdApproverStatus` and `WorldIdOrbVerification`, with a `WorldIdOrbVerificationStatus` enum parsed from the strings above;
   - an unknown status string throws `FormatException` (no silent default).
2. **`WorldIdApiService`** (`lib/features/world_id/remote/world_id_api_service.dart`):
   - `fetchApproverStatus()`, `startOrbVerification()`, `fetchOrbVerification(requestId)`, `bindLedgerApprover({requestId, signature})`;
   - register it in `lib/core/di/locator.dart` with `locator<ApiClient>()`.
3. **`X402ApprovalsCubit.signPersonalMessageOnLedger(String message) → Future<String>`:**
   - throws `StateError('Connect the approver Ledger first')` unless `state.isLedgerReady`;
   - otherwise emits `awaitingDevice` with `awaitingMessage: 'Confirm the World ID binding on your Ledger'`, signs `utf8.encode(message)` with the existing signer, returns the `0x` hex signature, and restores `idle`;
   - Ledger status-word errors map through the existing `_describeError`.
4. **`WorldIdApproverCubit`** (`lib/features/world_id/cubit/`):
   - **`loadStatus()`**.
   - **`startOrbVerification()`:** posts, stores the verification, polls `fetchOrbVerification` every 2 s with a `Timer`, and stops on `VERIFIED`, `BOUND`, `FAILED` or `EXPIRED`.
   - **`bindWithLedger(Future<String> Function(String message) signPersonalMessageOnLedger)`:** requires `VERIFIED` and a non-null `bindMessage`, signs it, posts the bind, sets the returned status and clears the verification.
   - **`cancelVerification()`:** stops polling and clears it.
   - **Errors:** surface `ApiException` messages in `errorMessage`.
   - **Cleanup:** cancel the timer in `close()`.
   - **Wiring:** provide it in `lib/app/app.dart`.
5. **Approvals screen** (`x402_approvals_screen.dart`): add a **World ID** card between the Ledger connection card and the blind-signing hint (extract it into its own widget file if the screen grows past about 600 lines).

   | State | Card content |
   |---|---|
   | Not configured (`isWorldIdConfigured == false`) | "World ID isn't configured on the backend." |
   | Verified | "Orb verified" badge plus `expiresAt` date |
   | Not verified | A **Verify with World ID** button. If `isWorldIdRequired`, add "Approvals are blocked until the Ledger approver is verified." |
   | Waiting or awaiting | Status text (Waiting for World ID / Confirm in World ID), **Copy link** (`Clipboard`) and **Open link** (see step 6), and **Cancel** |
   | `VERIFIED` | "Orb proof verified. Sign the binding on your Ledger." plus a **Sign binding on Ledger** button, enabled only when `X402ApprovalsState.isLedgerReady` (otherwise "Connect the approver Ledger above first") |
   | `FAILED` or `EXPIRED` | The error or "Verification expired" plus **Try again** |

   - **Simulator instructions:** when `environment == 'staging'`, the waiting state also shows: "Open simulator.worldcoin.org in your browser, pick an Orb-verified identity, and paste this link."
   - **Approve button:** disabled while `isWorldIdRequired && !isVerified`. Keep **Reject** enabled.
   - **After binding:** refresh the World ID status. If the backend returns `403` on approve, show its message; don't retry automatically.
6. **Open link:**
   - add `url_launcher`, pinned to an exact version (`flutter pub add url_launcher`, then pin the resolved version);
   - open with `LaunchMode.externalApplication`;
   - add the Android 11+ `<queries>` intent for `android.intent.action.VIEW` with `https` to `AndroidManifest.xml`;
   - if launching fails, show a SnackBar telling the user to use Copy link.
7. **Settings:**
   - replace the wallet-based `GET /world/selfie/status/:wallet` row with the approver status from `WorldIdApiService.fetchApproverStatus()`: label "Ledger approver World ID", values "Orb verified" / "Not verified" / "Not configured";
   - remove `Chapter2ApiService.fetchWorldIdStatus` and the `WorldIdStatus` model if nothing else uses them.

**Commits (Step-Lock, scope `mobile`):**
1. The models and API service, with tests.
2. The signing method on `X402ApprovalsCubit`, with tests.
3. `WorldIdApproverCubit` and its tests.
4. The Approvals screen card and approve gating.
5. `url_launcher` and the manifest.
6. Settings.

Stage explicit paths only. Another agent is working in `backend/` at the same time, so never stage anything outside `chapter2/` (and never `chapter2/ios/Podfile.lock`).

## Tests
- **Model parsing:** every status value parses; an unknown status throws.
- **`X402ApprovalsCubit.signPersonalMessageOnLedger`:** throws when the Ledger isn't ready; when ready, signs the UTF-8 bytes of the message and returns the hex (use the existing `_FakeLedgerEthereumSigner`).
- **`WorldIdApproverCubit`** (fake API service; drive the polling with a short interval or `fakeAsync`):
  - start → `WAITING_FOR_WORLD_APP` → `VERIFIED` stops polling;
  - `FAILED` surfaces `errorMessage` and stops polling;
  - `bindWithLedger` passes exactly `bindMessage` to the signer function, posts the returned signature, and ends `isVerified: true`;
  - `bindWithLedger` before `VERIFIED` makes no network call.
- **Goldens:** update existing ones only if they break, and review the new images.

Gate: `cd chapter2 && flutter analyze && flutter test`.

## Acceptance criteria
- [ ] The full flow works against the contract: start → link (copy/open) → polling → Ledger binding → "Orb verified".
- [ ] Approve is disabled while World ID is required and unverified, and the backend's `403` message is shown if reached.
- [ ] No fallback data: unknown statuses throw, and failures show real error messages. `connectorUrl` is never logged.
- [ ] `flutter analyze` is clean and `flutter test` passes. Report the test counts before and after.
- [ ] A release APK builds with `cd chapter2 && flutter build apk --release`. Report the path (expected `build/app/outputs/flutter-apk/app-release.apk`) and its size.

## 👤 Tester script (for the remote tester with the Ledger)
1. Install the APK and sign in.
2. **Approvals:** connect the Ledger over Bluetooth, with the Ethereum app open.
3. **World ID card:** tap **Verify with World ID**, then **Copy link**.
4. **Simulator:** in the phone's browser, open https://simulator.worldcoin.org, choose an **Orb-verified** identity, paste the link, and approve.
5. **Back in the app:** when it says the proof is verified, tap **Sign binding on Ledger** and confirm on the device.
6. **Check:** the card shows **Orb verified**. Once the backend requires World ID, approve an escalated payment on the Ledger.
