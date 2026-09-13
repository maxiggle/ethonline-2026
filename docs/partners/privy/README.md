# Chapter 2 × Privy

Chapter 2 lets companies give AI agents a spending budget, while humans stay in control. **Privy is how those humans sign in and get an on-chain identity.** Privy identity decides who owns which agent, which purchases and which account data.

Project overview: [README](../../../README.md)

## What Privy does in Chapter 2

1. **Google sign-in on mobile.** The Flutter app uses the Privy Flutter SDK (`privy_flutter`) to run Google OAuth, restore the session on launch, and log out.
2. **An embedded EVM wallet for every user.** After login, the app reads the user's Privy embedded Ethereum wallet. If a user has none, the backend creates one with Privy's server API (`createWallets`). That wallet is the user's on-chain identity, stored on their account and shown in Settings.
3. **Server-side token verification.** The app sends its Privy access token as a Bearer token. The backend verifies it with `@privy-io/server-auth` (`verifyAuthToken`), loads the user from Privy (`getUser`), and takes the wallet address from Privy itself, never from the client.
4. **Account scoping.** A `PrivyAuthGuard` protects every user-owned route: binding agents, creating and viewing purchase requests, treasury actions, mandates, and World ID. A user can only act on their own agents and purchases.
5. **Account lifecycle.** First login creates the user record (a returning user who deleted their account is reactivated as a new user). Deleting an account soft-deletes it locally and deletes the user from Privy (`deleteUser`).

**Why the agent doesn't use the Privy wallet:** the user's Privy wallet is the human's identity. The AI agent pays with its own separate key, and escalated payments are approved on a Ledger. That keeps the human's wallet and the agent's budget apart.

## Implementation

### Mobile (Flutter)
- [`chapter2/pubspec.yaml`](../../../chapter2/pubspec.yaml): the `privy_flutter` dependency.
- [`privy_manager.dart`](../../../chapter2/lib/features/auth/services/privy_manager.dart):
  - `Privy.init`
  - `loginWithGoogle` (`oAuth.login` with Google)
  - `getCurrentSession`
  - `logout`
  - access token and embedded wallet extraction
- [`auth_service.dart`](../../../chapter2/lib/features/auth/services/auth_service.dart): `loginWithPrivy` sends the Privy token to `POST /auth/login`; `checkSession` restores the session.
- [`api_client.dart`](../../../chapter2/lib/core/network/api_client.dart): attaches the Privy token as `Authorization: Bearer` on every API call.
- [`app_config.dart`](../../../chapter2/lib/core/config/app_config.dart): Privy app ID, client ID and URL scheme.

### Backend (NestJS)
- [`backend/package.json`](../../../backend/package.json): the `@privy-io/server-auth` dependency.
- [`privy-auth.service.ts`](../../../backend/src/auth/privy-auth.service.ts):
  - `PrivyClient` setup;
  - `verifyAuthToken` (token verification, `getUser`, embedded wallet resolution, `createWallets` provisioning);
  - `syncUser`;
  - `deleteUserAccount` (`deleteUser`).
- [`privy-auth.guard.ts`](../../../backend/src/auth/guards/privy-auth.guard.ts): Bearer token verification on protected routes.
- [`auth.controller.ts`](../../../backend/src/auth/auth.controller.ts): `POST /auth/login`, `GET /auth/me`, `DELETE /auth/account`.
- **Routes scoped by Privy identity:**
  - [`agents.controller.ts`](../../../backend/src/agents/agents.controller.ts): bind and list agents.
  - [`x402-purchase-requests.controller.ts`](../../../backend/src/x402/x402-purchase-requests.controller.ts): create, list and view service purchases.
  - [`world.controller.ts`](../../../backend/src/world/world.controller.ts): World ID binding for the signed-in wallet.

## Status
- Live: the mobile app signs users in with Google through Privy against the deployed backend on Render.
- Backend tests cover Privy login, profile, account deletion, user sync and re-activation of returning users.
