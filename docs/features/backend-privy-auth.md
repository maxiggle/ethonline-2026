# Privy Authentication, Dynamic Agent Binding & Account Lifecycle Management

## 1. Overview
Chapter 2 leverages **Privy** for seamless cryptographic identity management and institutional key provisioning. Every user is authenticated via Privy OAuth (Google or email) and receives an embedded EVM wallet address. This wallet serves as the user's primary supervisor key and bound autonomous agent identity, avoiding hardcoded fallback addresses.

To support user privacy, regulatory right-to-be-forgotten requests, and on-chain compliance, the platform provides a complete **Account Deletion & Lifecycle Management Flow**.

---

## 2. API Endpoints Catalog

### Authentication & Profile (`/auth`)

| Method | Endpoint | Auth | Purpose | Request Payload | Response |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `POST` | `/auth/login` | Public | Ingests Privy authentication token, verifies claims, provisions embedded EVM wallet if needed, and synchronizes profile with database. | `LoginDto`:<br>`authToken` (string)<br>`email?` (string)<br>`name?` (string)<br>`walletAddress?` (address) | `{ success: true, user: User, isNewUser: boolean }` |
| `GET` | `/auth/me` | Bearer | Returns the authenticated operator profile, email, and embedded EVM wallet address. | None | `{ success: true, user: User }` |
| `DELETE` | `/auth/account` | Bearer | Soft-deletes user account locally, deactivates bound agents, and deletes user record from Privy Cloud. | None | `{ success: true, message: string }` |

### Autonomous Agent Binding (`/agents`)

| Method | Endpoint | Auth | Purpose | Request Payload | Response |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `POST` | `/agents/bind` | Bearer | Binds the user's dynamic embedded EVM wallet or custom agent address to the Chapter2Guard on-chain mandate. | `BindAgentDto`:<br>`agentAddress` (address)<br>`name` (string)<br>`purpose?` (string)<br>`safeAddress` (address)<br>`guardAddress` (address)<br>`chainId` (number) | `{ success: true, agent: Agent }` |
| `GET` | `/agents` | Bearer | Lists all active autonomous agents registered under the authenticated user. | None | `{ success: true, agents: Agent[] }` |

---

## 3. Account Deletion & Soft-Delete Retention Architecture

When an operator requests account deletion via `DELETE /auth/account`:

```
┌───────────────────────────────────────────────────────────┐
│                    Mobile Settings Screen                 │
│         [Tap: Delete Account & Deactivate Agents]         │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│               Confirmation Modal (AlertDialog)            │
│  - Warns about Privy Cloud deletion & agent deactivation  │
│  - Reassures Base Sepolia on-chain audit receipt preservation
└─────────────────────────────┬─────────────────────────────┘
                              │ (Confirmed)
                              ▼
┌───────────────────────────────────────────────────────────┐
│              DELETE /auth/account (Bearer Token)          │
└─────────────────────────────┬─────────────────────────────┘
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
   ┌───────────────────────┐     ┌───────────────────────┐
   │    Backend Database   │     │      Privy Cloud      │
   │      (Soft Delete)    │     │     (Hard Delete)     │
   └───────────┬───────────┘     └───────────┬───────────┘
               │                             │
    • user.deletedAt = now         • privyClient.deleteUser(id)
    • agent.status = 'INACTIVE'    • Session invalidated
    • On-chain receipts intact
```

### Data Retention & Audit Guarantee
1. **Local Soft Delete (`"user"` Table)**:
   - Sets `"deletedAt" = CURRENT_TIMESTAMP` and `"updatedAt" = CURRENT_TIMESTAMP`.
   - Query filters (`WHERE "deletedAt" IS NULL`) prevent the deleted user from accessing protected endpoints (`/auth/me`, `/actions/*`, `/agents/*`).
2. **Autonomous Agent Deactivation (`agent` Table)**:
   - Updates bound agents belonging to the user to `status = 'INACTIVE'`.
   - Prevents further autonomous action proposal by deactivated agents.
3. **Audit Immutability**:
   - `treasury_actions`, `treasury_mandates`, and `daily_spent_ledger` records are permanently preserved.
   - All Base Sepolia blockchain transaction receipts, EIP-712 signatures, and risk scores remain immutable for regulatory auditing.
4. **Cloud Privacy Compliance (`Privy Cloud`)**:
   - Calls `privyClient.deleteUser(userId)` to erase personal identity credentials and OAuth tokens from Privy Cloud infrastructure.

---

## 4. Mobile Client Implementation

The Flutter mobile application exposes account deletion in `SettingsScreen` within the **Account & Privacy** card:

1. **Confirmation Dialog**:
   - Displays clear warning and explanation of consequences.
   - Clarifies that Base Sepolia on-chain receipts are retained for audit integrity.
2. **Destructive Execution**:
   - Invokes `AuthCubit.deleteAccount()`.
   - Calls `AuthService.deleteAccount()` -> `ApiClient.delete('/auth/account')`.
   - Calls `PrivyManager.logout()` to destroy cached tokens.
   - Transitions `AuthState` to `unauthenticated`.
   - Clears navigation stack and routes the user to `LoginRoute`.
