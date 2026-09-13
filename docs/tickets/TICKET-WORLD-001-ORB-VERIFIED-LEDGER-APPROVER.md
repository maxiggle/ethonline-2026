# TICKET WORLD-001: World ID Orb Verification Bound to the Ledger Approver (Backend)

**Time box:** 3 h · **Component:** `backend/` (NestJS) · **Depends on:** X402-002 (live) · **Parallel with:** MOBILE-004, which builds against the contract below · **Read first:** `docs/tickets/README.md`

## Why
- **The gap:** an escalated x402 payment is approved when the EIP-712 signature recovers to `LEDGER_APPROVER_ADDRESS`. That proves someone holds the Ledger, not that a unique human stands behind it.
- **The fix:** before the backend accepts a Ledger approval, the approver address must have an active **World ID Orb** binding. The human proves Orb uniqueness in World App (the World simulator in staging), then signs a binding message **on the same Ledger**, which ties the World identity and the Ledger key together.
- **Why Orb:** Selfie Check is access-gated by World and was never enabled for our app. Orb (`orbLegacy` preset) needs no extra approval, and it's the stronger credential.
- **Who tests:** a remote tester with the Ledger and an Android APK (MOBILE-004), using the World ID **staging** environment and the simulator at https://simulator.worldcoin.org.

**Out of scope:**
- **Legacy selfie code:** the `/world/selfie/*` routes and `WorldSelfieService` stay untouched. Do not reuse `verifySelfieProof`: its proof shape doesn't match World's API.
- **Rejections stay ungated:** refusing a payment can't move funds.
- **No web World ID step:** the web approval console gets no World ID step.

## Verified facts (checked 2026-09-13; don't re-derive, but do read the installed types)
- **Package:** `@worldcoin/idkit-core@4.2.4`; pin it exactly. It ships a CJS build (`dist/index.cjs`), so the backend's `module: node16` CJS output can `import { IDKit, orbLegacy } from '@worldcoin/idkit-core'`. Server-safe subpaths: `@worldcoin/idkit-core/signing` (`signRequest`) and `@worldcoin/idkit-core/hashing` (`hashSignal`).
- **IDKit runs server-side, with one workaround.** `IDKit.request()` initializes WASM by calling `fetch(new URL('idkit_wasm_bg.wasm', <file URL of dist/index.cjs>))`. Node's `fetch` rejects `file:` URLs, so it fails with `Failed to initialize IDKit WASM: TypeError: fetch failed`. Wrapping `globalThis.fetch` so that **only** a `file:` URL ending in `/idkit_wasm_bg.wasm` is served from disk (`new Response(bytes, { headers: { 'Content-Type': 'application/wasm' } })`) makes it work. A probe with this shim created a real staging request: `connectorURI` = `https://staging.world.org/verify?t=…&i=…&k=…`, and `pollOnce()` returned `{"type":"waiting_for_connection"}`.
- **`signRequest({ signingKeyHex, action, ttl })`** returns `{ sig, nonce, createdAt, expiresAt }`. `ttl` is in seconds (default 300). Map it into `rp_context` as `{ rp_id, nonce, created_at: createdAt, expires_at: expiresAt, signature: sig }`.
- **`IDKit.request(config).preset(orbLegacy({ signal }))`** resolves to an `IDKitRequest` with `connectorURI`, `requestId`, `pollOnce(): Promise<{ type: 'waiting_for_connection' | 'awaiting_confirmation' | 'confirmed' | 'failed', result?, error? }>`.
  - **Config:** `{ app_id: 'app_…', action, rp_context, allow_legacy_proofs: true, environment: 'staging' | 'production' }`.
  - **Proof version:** `orbLegacy` returns **World ID 3.0** proofs only.
- **Verify:** `POST https://developer.world.org/api/v4/verify/{rp_id}`. Send the IDKit result **as-is** (no remapping).
  - **3.0 result:** `{ protocol_version: '3.0', nonce, action, environment, responses: [{ identifier: 'orb', signal_hash, merkle_root, nullifier, proof }] }`. Confirm field names against `ResponseItemV3` in the installed `index.d.ts`.
  - **Success:** `200 { success: true, results: [{ identifier, success, nullifier?, code?, detail? }], … }`.
  - **Errors:** `400`/`404` return `{ success: false, code, detail }`.
- **Signal binding:** the proof carries only `signal_hash`. Compare it with `hashSignal(signal)` using the **exact same string** you passed as `signal` (use the checksummed approver address).
- **Security:** `connectorURI` contains the request's decryption key (`k`). Never log it, and return it only to the user who started the request.

## Configuration (no fallbacks)
Add a loader `backend/src/world/world-id.config.ts` (`loadWorldIdConfig()`):

| Variable | Rule |
|---|---|
| `REQUIRE_WORLD_ID_FOR_ESCALATIONS` | **Required.** Exactly `true` or `false`; anything else is a startup error. |
| `WORLD_ID_APP_ID` | Starts with `app_` |
| `WORLD_ID_RP_ID` | Starts with `rp_` |
| `WORLD_ID_SIGNING_KEY` | 32-byte hex, optional `0x`; secret, never logged |
| `WORLD_ID_ACTION` | Non-empty, e.g. `chapter2-ledger-approver` |
| `WORLD_ID_ENVIRONMENT` | Exactly `staging` or `production` |

- **All five `WORLD_ID_*` set:** World ID is configured.
- **None set:** World ID is unconfigured, and the start route returns `503`.
- **Some but not all set:** startup error naming the missing ones.
- **`REQUIRE_WORLD_ID_FOR_ESCALATIONS=true` while unconfigured:** startup error.
- **Approver address:** comes from `LEDGER_APPROVER_ADDRESS` (reuse `loadX402Config`). To avoid a circular import, `WorldModule` may register its own `{ provide: X402_CONFIG, useFactory: loadX402Config }`.
- **Deploy files:** add the six variables to `backend/.env.example` (empty values) and to `render.yaml` with `sync: false`.

## API contract (MOBILE-004 builds against this; don't change it without updating both tickets)
All routes use `PrivyAuthGuard`.

| Call | Response |
|---|---|
| `GET /world/approver/status` | `200` `ApproverStatus` |
| `POST /world/approver/orb-verifications` | `201` `OrbVerification`; `503` if World ID is unconfigured |
| `GET /world/approver/orb-verifications/:requestId` | `200` `OrbVerification`; `404` if unknown **or started by another user** |
| `POST /world/approver/orb-verifications/:requestId/bind` body `{ signature }` | `200` `ApproverStatus` |

**Bind errors:**
- `400`: malformed signature.
- `401`: signature doesn't recover to the approver.
- `404`: unknown request, or another user's.
- `409`: not `VERIFIED`, or already expired.

```ts
type ApproverStatus = {
  approverAddress: string;
  isWorldIdRequired: boolean;
  isWorldIdConfigured: boolean;
  environment: 'staging' | 'production' | null;
  isVerified: boolean;
  credential: 'orb' | null;
  boundAt: string | null;
  expiresAt: string | null;
};

type OrbVerification = {
  requestId: string;
  status: 'WAITING_FOR_WORLD_APP' | 'AWAITING_CONFIRMATION' | 'VERIFIED' | 'BOUND' | 'FAILED' | 'EXPIRED';
  connectorUrl: string | null;
  expiresAt: string;
  bindMessage: string | null;
  errorMessage: string | null;
};
```

**Field rules:**
- **`approverAddress`:** checksummed.
- **`isVerified`:** an active, unexpired binding exists.
- **`credential`, `boundAt`, `expiresAt`:** set only when `isVerified` is true.
- **`connectorUrl`:** set only while the status is `WAITING_FOR_WORLD_APP` or `AWAITING_CONFIRMATION`.
- **`bindMessage`:** `chapter2-world-bind:<nullifier>`, set only when the status is `VERIFIED`.
- **`errorMessage`:** set only when the status is `FAILED`.

## Implementation
Keep the naming precise: `humanSigner`, `ledgerApproverAddress`, `isWorldIdRequired`. No banner comments.

1. **`idkit-node-wasm-loader.ts`:** `installIdkitWasmFileFetch()`.
   - Idempotent.
   - Wraps `globalThis.fetch` so a `file:` URL whose path ends with `/idkit_wasm_bg.wasm` is read from disk and returned as `application/wasm`.
   - Every other request goes to the original `fetch` unchanged.
   - One short comment explaining why (Node's `fetch` has no `file:` support, and IDKit's WASM loader relies on it).
2. **`world-id-request.client.ts`:** injectable, provided under a token so tests can replace it.
   - `createOrbRequest(signal: string)` calls `installIdkitWasmFileFetch()`, then `signRequest({ signingKeyHex, action, ttl: 900 })`, then `IDKit.request({... environment, allow_legacy_proofs: true }).preset(orbLegacy({ signal }))`.
   - Returns `{ requestId, connectorUrl, pollOnce }`.
3. **`world-id-verify.client.ts`:** injectable, provided under a token.
   - `verifyProof(result)` POSTs to `https://developer.world.org/api/v4/verify/${rpId}` and returns the parsed body.
   - On a non-2xx response, throws an error that includes World's `code` and `detail`.
4. **`world-id-approver.service.ts`:** keeps verification sessions in memory (`Map<requestId, session>`, each owned by a Privy user id, expiring 15 minutes after creation).
   - **`startOrbVerification(userId)`:**
     - `signal` = the checksummed `ledgerApproverAddress`.
     - Creates the request and stores the session as `WAITING_FOR_WORLD_APP`.
     - Starts a background loop that calls `pollOnce()` every 2 s until `confirmed`, `failed` or expiry, and moves the session to `AWAITING_CONFIRMATION` on `awaiting_confirmation`.
     - Returns immediately.
     - The loop must never throw unhandled; every failure becomes `FAILED` with a human-readable `errorMessage` (include IDKit error codes such as `rp_signature_expired`, `unknown_rp`, `invalid_rp_signature`).
   - **On `confirmed`, run these checks in order** (each failure → `FAILED`):
     1. World verify succeeds, and the `orb` result has `success: true`.
     2. `result.action === WORLD_ID_ACTION`.
     3. A response item with `identifier === 'orb'` exists.
     4. Its `signal_hash` equals `hashSignal(signal)` (case-insensitive hex compare).
     5. Its `nullifier` (lowercased) isn't bound to a **different** signer in `human_bindings` (`SELECT * FROM human_bindings WHERE nullifier_hash = ?`).

     Then set `VERIFIED` and store the nullifier and `bindMessage`.
   - **`getOrbVerification(userId, requestId)`:** returns the session. Unknown or other users' requests → `NotFoundException`. Past expiry and not `BOUND` → `EXPIRED`.
   - **`bindLedgerApprover(userId, requestId, signature)`:**
     - Requires `VERIFIED` and not expired (`ConflictException`).
     - `verifyMessage(bindMessage, signature)` must equal the approver (`UnauthorizedException`); a malformed signature is `BadRequestException`.
     - Re-runs the nullifier check.
     - Writes `INSERT OR REPLACE INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)` with the checksummed approver and `expires_at` = now + 90 days. The `DatabaseService` translates this for Postgres.
     - Sets the session to `BOUND` and returns `getApproverStatus()`.
   - **`getApproverStatus()`:** reads `human_bindings` for the approver.
   - **`assertLedgerApproverVerifiedForApproval()`:**
     - When `isWorldIdRequired` and there's no active binding → `ForbiddenException('The Ledger approver has no active World ID Orb verification')`.
     - When a binding is active → extend `expires_at` to now + 90 days (`UPDATE human_bindings SET expires_at = ? WHERE signer_address = ?`).
     - When not required → no-op.
5. **`world-id-approver.controller.ts`:** the four routes above (`@Controller('world/approver')`, `@UseGuards(PrivyAuthGuard)`, DTO with `@IsString() @IsNotEmpty() signature`). Register it, the service, both clients and the config in `WorldModule`, and export the service.
6. **The gate:**
   - `X402Module` imports `WorldModule`, and `X402PaymentsService` injects `WorldIdApproverService`.
   - In `approveWithSignature`, call `assertLedgerApproverVerifiedForApproval()` **after** the signature recovers to the approver and **before** the `UPDATE x402_escalations`.
   - `rejectWithSignature` is unchanged.
   - Update any spec that constructs these providers.
7. **Docs:** `docs/features/world-id-orb-ledger-approver.md` (overview, flow, API, env vars, trade-offs):
   - sessions are in memory, so a restart drops unfinished verifications;
   - staging proofs are test identities;
   - the World ID proof and the Ledger signature must be completed in the same signed-in session within 15 minutes.

**Commits (Step-Lock, scope `backend`):**
1. Config loader and WASM loader, with tests.
2. The request and verify clients.
3. The approver service and its tests.
4. The controller, module and spec.
5. The payments gate and module import.
6. The env example and `render.yaml`.
7. `docs(features): …`

Stage explicit paths only. Another agent is working in `chapter2/` at the same time, so never stage anything outside `backend/`, `render.yaml` or your docs file.

## Tests (jest, no network)
Use fake request and verify clients and a random `ethers.Wallet` as the approver.
- **Config:** missing or invalid `REQUIRE_WORLD_ID_FOR_ESCALATIONS`, partial `WORLD_ID_*`, bad prefixes, and `true` while unconfigured all throw; all five set loads.
- **WASM loader:** serves bytes for an `idkit_wasm_bg.wasm` file URL; delegates an `https:` URL to the original fetch.
- **Service, happy path:** start → poll `awaiting_confirmation` → `confirmed` with a valid orb item → `VERIFIED` with `bindMessage`.
- **Service, failures:**
  - wrong `signal_hash`, `identifier: 'device'`, an action mismatch, verify returning `400 { code, detail }`, and IDKit `failed` with `rp_signature_expired` each end `FAILED` with a readable message;
  - a nullifier bound to another signer → `FAILED`.
- **Bind:**
  - the approver's signature → binding stored and `isVerified: true`;
  - another wallet's signature → `401`;
  - binding before `VERIFIED` → `409`;
  - another user's `requestId` → `404`.
- **Gate:**
  - required and unverified → `403` from `approveWithSignature`, and the escalation stays `AWAITING`;
  - required and verified → the approval succeeds and `expires_at` is extended;
  - not required → the approval succeeds without a binding.
- **Controller spec:** routes and status codes, with `.overrideGuard(PrivyAuthGuard)`.

Gate: `cd backend && npx tsc --noEmit -p tsconfig.json && npx jest --runInBand --forceExit --testPathIgnorePatterns on-chain-executor.service.spec`. All existing tests must still pass.

## Acceptance criteria
- [ ] The six variables are validated at startup exactly as specified, with no defaults. The old `DEFAULT_WORLD_*` constants are **not** used by any new code.
- [ ] The four routes match the contract, including ownership (`404`) and the `connectorUrl` and `bindMessage` visibility rules. `connectorUrl` never appears in logs.
- [ ] A proof is accepted only if World's verify API succeeds **and** `identifier === 'orb'`, the action matches, `signal_hash === hashSignal(checksummed approver)`, and its nullifier isn't bound to another signer.
- [ ] Binding requires an EIP-191 signature of `chapter2-world-bind:<nullifier>` that recovers to `LEDGER_APPROVER_ADDRESS`.
- [ ] With `REQUIRE_WORLD_ID_FOR_ESCALATIONS=true`, `POST /x402/approvals/:id/signature` returns `403` for an unbound approver and succeeds once the approver is bound. Rejections are never gated.
- [ ] The backend gate passes. Report the test counts before and after.
- [ ] **Report** anything in the installed IDKit types that differs from "Verified facts" (e.g. `ResponseItemV3` field names).

## 👤 Human steps (the user, not the agent)
1. **Developer Portal (developer.world.org):**
   - Open the World ID 4.0 app and copy the **app ID** (`app_…`), **RP ID** (`rp_…`) and **signing key**. Never paste the key into chat or commit it.
   - Make sure the app can be used with **staging**/the simulator.
   - If the portal requires actions to be registered, create `chapter2-ledger-approver`.
2. **Render → chapter2-backend → Environment:**
   - set the five `WORLD_ID_*` variables (`WORLD_ID_ENVIRONMENT=staging`);
   - start with `REQUIRE_WORLD_ID_FOR_ESCALATIONS=false`;
   - set `LEDGER_APPROVER_ADDRESS` to the **tester's Ledger address** (the binding must be signed by that Ledger).
3. **After the tester binds the Ledger** (MOBILE-004), set `REQUIRE_WORLD_ID_FOR_ESCALATIONS=true`, redeploy, and confirm that an escalated approval still succeeds.
4. **Live smoke check** after deploy, from the app: starting a verification returns a `connectorUrl` beginning with `https://staging.world.org/verify`.
