# Feature Documentation: Backend API Gateway & WebSocket Event Stream

## 1. Overview
The **Backend API Gateway & WebSocket Event Stream** provides the unified supervisory interface and real-time reactive transport for Chapter 2. It bridges autonomous AI treasury agents, the Guardian risk engine, World ID biometric proof-of-personhood, Ledger hardware clear-signing, and the Flutter mobile command center.

The gateway provides:
1. **Actions Controller & Lifecycle State Machine** ([ActionsController](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/actions/actions.controller.ts) & [ActionStoreService](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/actions/action-store.service.ts)):
   - Ingests proposals from autonomous treasury agents via `POST /actions/propose`.
   - Coordinates atomic balance reservations via `BalanceReservationService`.
   - Executes deterministic policy validation and adversarial NLP evaluation via `RiskAnalysisService`.
   - Implements tri-verdict resolution:
     - `ALLOW`: Commits reservation, marks status `APPROVED`, and emits `action:approved`.
     - `ESCALATE`: Holds reservation, marks status `PENDING`, generates EIP-712 typed data envelope, formats clear-signing prompt, and emits real-time `action:escalated` alert to mobile operators.
     - `BLOCK`: Releases balance reservation, marks status `REJECTED`, and emits `action:blocked`.
   - Enforces human clear-signing approvals (`POST /actions/:id/approve`), validating EIP-712 cryptographic signatures against authorized hardware or World ID verified operators, refreshing 90-day inactivity timers, and packing Safe execution bytes (`abi.encode(approval, sig)`).
2. **World ID Selfie Check Controller** ([WorldController](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/world/world.controller.ts)):
   - Exposes REST endpoints for Credential 11 (Selfie Check Beta) zero-knowledge proof verification, human signer binding, 90-day lifecycle status inspection, and revocation.
3. **Ledger Key Ring Controller** ([LedgerController](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/ledger/ledger.controller.ts)):
   - Exposes hardware connection telemetry, clear-sign prompt generation, automated signing adapters, and LKRP secret vault queries.
4. **Real-Time WebSocket Gateway** ([EventsGateway](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/backend/src/gateway/events.gateway.ts)):
   - Real-time Socket.io push channel enabling instantaneous notification to mobile devices when autonomous agents propose high-risk actions requiring physical clear-signing.

---

## 2. API Endpoints Catalog

### A. Actions Service (`/actions`)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/actions/propose` | Submits new treasury proposal. Executes risk analysis and reservation logic. Returns `ActionResponseDto`. |
| `GET` | `/actions` | Lists all actions with optional query parameter `?status=PENDING\|APPROVED\|REJECTED`. |
| `GET` | `/actions/pending` | Lists all actions currently awaiting human review/approval. |
| `GET` | `/actions/:id` | Fetches details and status of a specific action. |
| `GET` | `/actions/:id/clear-sign` | Generates transparent clear-signing prompt with formatted USD amounts and recipient details. |
| `POST` | `/actions/:id/approve` | Submits EIP-712 approval signature. Validates signer authorization, updates status, and returns Safe ABI execution payload. |
| `POST` | `/actions/:id/reject` | Rejects pending action and releases balance reservation. |

### B. World ID Credential 11 Service (`/world/selfie`)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/world/selfie/verify` | Directly validates World ID Credential 11 or Orb ZK-proof payload. |
| `POST` | `/world/selfie/bind` | Atomically binds human nullifier to signer address with 90-day inactivity window. |
| `GET` | `/world/selfie/status/:signerAddress` | Returns active verification status and binding details. |
| `GET` | `/world/selfie/bindings` | Enumerates all active human signer bindings. |
| `DELETE` | `/world/selfie/bindings/:signerAddress` | Revokes human binding and unbinds nullifier. |

### C. Ledger Hardware & Key Ring Service (`/ledger`)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/ledger/status` | Reports hardware connection status, mode (`MOCK_HARDWARE` / `HEADLESS_CLI`), model, and address. |
| `GET` | `/ledger/signer` | Returns checksummed authorized hardware signer address. |
| `POST` | `/ledger/clear-sign-prompt` | Formats clear-signing layout preventing blind signing on device screens. |
| `POST` | `/ledger/sign` | Signs typed approval payload with the active hardware/mock key. |
| `GET` | `/ledger/keys` | Enumerates encrypted agent secrets in the LKRP key ring vault. |

---

## 3. Real-Time WebSocket Event Catalog (`EventsGateway`)

| Event Name | Direction | Description | Payload |
| :--- | :--- | :--- | :--- |
| `subscribe:actions` | Client $\rightarrow$ Server | Subscribes client to `actions_channel` room. | `{}` |
| `ping` | Client $\rightarrow$ Server | Heartbeat check. | `{}` (Responds with `pong`) |
| `action:proposed` | Server $\rightarrow$ Client | Dispatched when a new action is proposed. | `{ action, timestamp }` |
| `action:escalated` | Server $\rightarrow$ Client | **Critical Push**: Escalates high-risk action to mobile command center. | `{ action, decision, typedData, prompt, timestamp }` |
| `action:approved` | Server $\rightarrow$ Client | Dispatched when action is approved. | `{ action, executionPayload, safeTxData, timestamp }` |
| `action:rejected` | Server $\rightarrow$ Client | Dispatched when action is rejected. | `{ action, reason, timestamp }` |
| `action:blocked` | Server $\rightarrow$ Client | Dispatched when action is blocked. | `{ action, decision, timestamp }` |

---

## 4. Test Coverage Matrix (93 / 93 Tests Passing across 10 Suites)

| Test Suite | File | Tests Passing | Scenarios Covered |
| :--- | :--- | :--- | :--- |
| **Actions Controller** | `actions.controller.spec.ts` | 12 / 12 | Tri-verdict intake (`ALLOW`, `ESCALATE`, `BLOCK`).<br>Balance reservation allocation and rollback.<br>EIP-712 typed data generation for escalated actions.<br>Hardware signature verification and Safe payload packing.<br>Rejection and double-approval prevention.<br>Action listing and pending query filters. |
| **Events Gateway** | `events.gateway.spec.ts` | 8 / 8 | Client connection lifecycle, ping/pong, room subscriptions, and typed event emissions for all 5 lifecycle states. |
| **World Controller** | `world.controller.spec.ts` | 8 / 8 | Credential 11 ZK proof verification, human binding, status checking, binding enumeration, and revocation. |
| **Ledger Controller** | `ledger.controller.spec.ts` | 6 / 6 | Device status telemetry, address reporting, prompt formatting, EIP-712 signing, and secret vault enumeration. |
| **World Selfie Service** | `world-selfie.service.spec.ts` | 15 / 15 | ZK verification, anti-Sybil replay defense, 90-day expiration, and activity refresh. |
| **Ledger Key Ring Service** | `ledger-keyring.service.spec.ts` | 11 / 11 | LKRP AES-256-GCM secret management, clear-sign prompt layout, and Safe ABI encoding. |
| **Crypto EIP-712 Service** | `eip712.service.spec.ts` | 11 / 11 | Domain separator, struct hashing, signature recovery, and Base Sepolia contract parity. |
| **Guardian Risk Engine** | `risk-analysis.service.spec.ts` | 11 / 11 | Adversarial NLP classifiers, prompt injection detection, and risk scoring. |
| **Deterministic Policies** | `policy-engine.service.spec.ts` | 6 / 6 | Caps, recipient whitelist, and rolling limits. |
| **Balance Reservations** | `balance-reservation.service.spec.ts` | 5 / 5 | Atomic balance reservation, concurrency locks, and daily budget tracking. |

---

## 5. Verification Commands

```bash
# Run unit tests for API gateway components
cd backend && npm test -- actions.controller.spec.ts
cd backend && npm test -- world.controller.spec.ts
cd backend && npm test -- ledger.controller.spec.ts
cd backend && npm test -- events.gateway.spec.ts

# Run all 10 backend test suites (93 tests)
cd backend && npm test

# Run build compilation check
cd backend && npm run build
```
