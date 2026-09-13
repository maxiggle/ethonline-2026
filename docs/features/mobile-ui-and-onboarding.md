# Feature Documentation: Mobile UI, Navigation and Onboarding

## 1. Overview
The Flutter app was rebuilt into a small, readable product that shows only real data:
- one accessible dark theme;
- four tabs (**Home, Services, Approvals, Activity**), with Settings behind a header icon;
- a three-step onboarding that binds a real agent address and connects the Ledger approver.

The earlier UI mixed light and dark palettes, so text blended into backgrounds. It also contained simulated flows: a fake World ID proof, a hardcoded "Ledger paired" switch, placeholder biometric signatures, and scripted payment scenarios. All of these were removed.

Ticket: [TICKET-MOBILE-002](../tickets/TICKET-MOBILE-002-SIMPLIFY-UI-AND-ONBOARDING.md). The Services tab has its own doc: [mobile-services-tab.md](mobile-services-tab.md).

## 2. How It Was Built

### Theme
- **Tokens:** one dark palette in [`app_colors.dart`](../../chapter2/lib/shared/theme/app_colors.dart): background, surface, raised surface, border, primary/secondary/muted text, primary, and verdict colors.
- **Theme:** [`chapter2_theme.dart`](../../chapter2/lib/shared/theme/chapter2_theme.dart) builds a complete Material `ThemeData`, so built-in widgets (sheets, dialogs, inputs, switches, snack bars, navigation bar) stay readable without per-widget overrides.
- **Contrast test:** [`test/theme/contrast_test.dart`](../../chapter2/test/theme/contrast_test.dart) enforces WCAG contrast.
  - Primary and secondary text: at least 7:1 on every surface.
  - Muted text and verdict colors: at least 4.5:1.
  - Text on primary buttons: at least 4.5:1.

### Navigation
- **Shell:** [`main_shell_screen.dart`](../../chapter2/lib/features/shell/main_shell_screen.dart) is a Material 3 `NavigationBar`.
- **Programmatic tab switching:** [`shell_tab_controller.dart`](../../chapter2/lib/features/shell/shell_tab_controller.dart), used for example to open Approvals from an escalated purchase.

### Home
[`dashboard_screen.dart`](../../chapter2/lib/features/dashboard/view/dashboard_screen.dart) shows three cards, each with loading, empty and error states:
- **Agent:** name, address and status from `GET /agents`, or a **Bind your agent** call to action.
- **Ledger approvals:** the pending count from `GET /x402/approvals/pending`.
- **Recent activity:** the latest actions with verdict chips.

### Onboarding
[`onboarding_screen.dart`](../../chapter2/lib/features/onboarding/view/onboarding_screen.dart):
1. **Welcome:** agents pay with x402, the Guardian decides, big payments are approved on your Ledger.
2. **Bind your agent:**
   - The user pastes the agent wallet address (validated `^0x[a-fA-F0-9]{40}$`); it's never the Privy wallet.
   - Safe and Guard addresses come from `GET /mandates/active`. If that fails, the step shows the error with Retry and doesn't bind.
   - Binding calls `POST /agents/bind` and refreshes the agents list. Backend errors show inline.
3. **Connect your Ledger approver:**
   - Reuses the Approvals cubit to scan, connect and compare with `approverAddress`.
   - **Finish** appears only after a matching Ledger connects. **I'll connect later** goes to Home.

### Settings
[`settings_screen.dart`](../../chapter2/lib/features/settings/view/settings_screen.dart):
- **Account:** name, email and Privy wallet from the auth state.
- **Backend:** the backend URL and the approver address.
- **World ID:** status from `GET /world/selfie/status/:wallet`, or "Not configured". It never shows a hardcoded "Verified".
- **Delete account and sign out:** both capture the router before awaiting, so navigation to Login always happens.

### Removed
- The legacy bills screen (the `/vendor/*` rail).
- The legacy approval sheet with its placeholder signature.
- The agent detail and mandate sheets with simulated controls.
- The dashboard's scripted payment scenarios.
- The sparkline built on invented data.
- The unused API models.

In total about 8,900 lines were removed.

## 3. Data Flow & Interfaces
```
Login (Privy) → POST /auth/login → isNewUser ? Onboarding : Home
Onboarding step 2 → GET /mandates/active → POST /agents/bind → GET /agents
Onboarding step 3 → GET /x402/approvals/config → Bluetooth GET ADDRESS → match / mismatch
Home → GET /agents, GET /x402/approvals/pending, GET /actions
Settings → GET /x402/approvals/config, GET /world/selfie/status/:wallet, DELETE /auth/account
```

## 4. Trade-offs / Edge Cases
- **Screenshot tests:** [`chapter2/test/screenshots`](../../chapter2/test/screenshots) renders every main screen with real fonts into [`goldens/`](../../chapter2/test/screenshots/goldens) for visual review. Their fake data lives only in test fixtures.
- **Pasting the agent address:**
  - It's secure (the agent's key stays on the agent machine), but clunky.
  - Binding doesn't yet prove key control.
  - A QR pairing flow with a signed challenge is the planned improvement.
- **Returning users:**
  - A deleted account that signs in again is reactivated as a new user and sees onboarding.
  - Re-binding a previously bound address reactivates that agent.
  - Binding an address another account has active returns `409`.
