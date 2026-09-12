# Feature Documentation: Render Cloud Backend & PostgreSQL Deployment

## 1. Overview
This document specifies the architecture, blueprint configuration, and operational lifecycle for deploying the **Chapter 2** supervisory NestJS backend and its associated PostgreSQL persistence database to **Render**. It also details how the Flutter mobile command center (`chapter2`) connects to the live cloud infrastructure via HTTPS REST and WSS Socket.io streaming.

---

## 2. How It Was Built

### 2.1 Infrastructure as Code (`render.yaml`)
A canonical Render Blueprint file (`render.yaml`) resides in the monorepo root to automate reproducible multi-service provisioning:
- **Managed Database (`chapter2-postgres`)**:
  - Engine: PostgreSQL
  - Database: `chapter2_db`
  - User: `chapter2`
  - Region: `oregon` (or matching web service)
- **Web Service (`chapter2-backend`)**:
  - Runtime: Node 20
  - Root Directory: `backend`
  - Build Command: `npm install && npm run build`
  - Start Command: `npm run start:prod`
  - Healthcheck Endpoint: `/mandates/active`
  - Port: `10000` (Render default HTTP routing port)

### 2.2 PostgreSQL SSL & Cloud Adaptation (`DatabaseService`)
When connecting to Render Managed PostgreSQL, connection strings utilize TLS encryption. `DatabaseService` was updated to conditionally configure SSL:
- Automatically detects `render.com`, `sslmode=require`, or `DATABASE_SSL=true`.
- Sets `ssl: { rejectUnauthorized: false }` to prevent self-signed certificate rejections on managed cloud endpoints.
- Extends initialization connection timeout to 10,000ms to accommodate initial cloud connection handshakes.

### 2.3 Mobile Dynamic URL Routing (`chapter2`)
The Flutter mobile application abstracts the backend host inside `AppConfig`:
- **Single Source of Truth**: `AppConfig.backendBaseUrl` defaults to `https://chapter2-backend.onrender.com` while honoring compile-time `--dart-define=BACKEND_BASE_URL=...` and `.env`.
- **Dynamic WebSocket Resolution**: `AppConfig.websocketUrl` automatically translates `https://` $\rightarrow$ `wss://` and `http://` $\rightarrow$ `ws://`.
- **Service Locator Integration**: `setupServiceLocator()` binds both `ApiClient` and `Chapter2SocketService` to the configured endpoints without hardcoded localhost fallbacks.

---

## 3. Data Flow & Interfaces

```
┌─────────────────────────────────────────────────────────────┐
│             Flutter Mobile Command Center                   │
│          (io.chapter2.app / AppConfig.backendBaseUrl)       │
└──────────────┬──────────────────────────────┬───────────────┘
               │ HTTPS                        │ WSS
               ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│             Render Cloud Web Service                        │
│            (https://chapter2-backend.onrender.com)          │
│                                                             │
│   • Health Check: GET /mandates/active                      │
│   • Actions Intake: POST /actions/propose                   │
│   • Clear-Signing Approvals: POST /actions/:id/approve      │
│   • Socket.io Gateway: EventsGateway (port 10000)           │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│   Render PostgreSQL DB      │ │   Base Sepolia RPC (84532)  │
│  (Internal DATABASE_URL)    │ │   • Chapter2Guard Contract  │
│  • users & agents           │ │   • Gnosis MockSafe         │
│  • treasury_actions         │ │   • Live USDC / ETH balance │
│  • daily_spent_ledger       │ │                             │
└─────────────────────────────┘ └─────────────────────────────┘
```

---

## 4. Step-by-Step Deployment Instructions

### Option A: Deploying via Render Dashboard (Recommended)
1. Open the [Render Dashboard](https://dashboard.render.com).
2. Click **New +** $\rightarrow$ **Blueprint**.
3. Connect your GitHub account and select repository `maxiggle/ethonline-2026`.
4. Choose the `feature/privy-auth-wallets` (or `development`) branch.
5. Render detects `render.yaml` and displays the Blueprint resource creation plan:
   - PostgreSQL: `chapter2-postgres`
   - Web Service: `chapter2-backend`
6. Enter the required private secrets marked `sync: false`:
   - `RELAYER_PRIVATE_KEY`: Private key funded on Base Sepolia.
   - `DEPLOYER_PRIVATE_KEY`: Deployer private key.
   - `PRIVY_APP_SECRET`: Privy application secret.
7. Click **Apply**. Render provisions the database and deploys the backend.

### Option B: Deploying via Render CLI
1. Log in to Render in your local terminal:
   ```bash
   render login
   ```
2. Link your active workspace:
   ```bash
   render workspace set <WORKSPACE_ID>
   ```
3. Validate and trigger the deployment:
   ```bash
   render blueprints validate ./render.yaml
   ```

---

## 5. Verification Commands

### Cloud Healthcheck Verification
Once deployed, verify the live cloud service responds with verified on-chain metrics:
```bash
curl -s https://chapter2-backend.onrender.com/mandates/active | jq .
```
Expected output:
```json
{
  "chainId": 84532,
  "safeAddress": "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
  "guardAddress": "0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3",
  "maxAutonomousAmountUsdc": 100,
  "dailyAutonomousLimitUsdc": 500,
  "currentDailySpentUsdc": 0,
  "remainingDailyBudgetUsdc": 500
}
```

### Mobile App Target Execution
To run the Flutter mobile app pointing directly to the deployed Render backend:
```bash
cd chapter2 && flutter run --dart-define=BACKEND_BASE_URL=https://chapter2-backend.onrender.com
```
