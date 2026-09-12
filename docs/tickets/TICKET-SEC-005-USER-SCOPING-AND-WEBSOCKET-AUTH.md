# TICKET SEC-005: Per-User Data Scoping & WebSocket Authentication

**Component:** `backend/` · **Priority:** Medium · **Read first:** `docs/tickets/README.md`

## Problem
All routes now require a logged-in user, but reads are not scoped to that user.
1. **Actions leak across users.** `GET /actions`, `GET /actions/pending`, `GET /actions/:id` and `GET /actions/:id/clear-sign` (`backend/src/actions/actions.controller.ts`) return every user's treasury actions.
2. **Vendor data is global.** `GET /vendor/accounts` and `GET /vendor/bills` return global in-memory lists, and `connectAccount` / `disconnectAccount` affect every user. `VendorService` keeps `connectedAccounts` / `bills` in memory with no owner.
3. **The WebSocket is open to anyone.** `EventsGateway` (`backend/src/gateway/events.gateway.ts`) accepts any connection (`cors: '*'`) and broadcasts every action event to all clients with `server.emit`.

## Implementation
1. **Scope actions:** add `agentsService.getAgentsForUser(userId)` and filter by the user's agent addresses.
   - List routes: take `@Req() request: AuthenticatedRequest` and return only actions whose `agentAddress` belongs to the user.
   - `:id` routes: 404 when the action isn't the user's (don't reveal that it exists).
   - Keep the existing internal methods for `VendorService` and specs, as the controller already does for propose, approve and reject.
2. **Scope vendor data:** add an owner `userId` to `ConnectedAccount` and `CompanyBill`, and persist both through `DatabaseService` following the existing table pattern. List and mutate only the caller's records. Bill payment must check the bill belongs to the caller.
3. **Authenticate the WebSocket:**
   - Verify the Privy token on connection (`handshake.auth.token`) with `PrivyAuthService.verifyAuthToken`, and disconnect on failure.
   - Join the socket to room `user:<userId>`.
   - Emit action events only to the room of the user who owns the action's agent, not `server.emit`.
   - Restrict CORS to configured origins (`CORS_ORIGINS` env).
3a. **Mobile impact:** `chapter2/lib/services/websocket/chapter2_socket_service.dart` must send the token in the handshake. This touches the Flutter app, so coordinate with PAY-005 or include a minimal change here with `flutter analyze && flutter test`.
4. **Tests:**
   - User A can't list, get, clear-sign, pay or disconnect user B's data.
   - The gateway rejects connections without a valid token and emits only to the owner room. Update the `events.gateway.spec.ts` expectations.

## Acceptance criteria
- **Isolation:** no authenticated endpoint or socket event exposes another user's actions, bills, accounts or bindings.
- **Gates:** the backend gate passes, and the mobile gate passes if the socket client changed.
