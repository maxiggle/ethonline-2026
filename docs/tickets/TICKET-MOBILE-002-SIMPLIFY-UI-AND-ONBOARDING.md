# TICKET MOBILE-002: Simplify the App, Fix Contrast, and Make Onboarding Real

**Time box:** 3 h · **Component:** `chapter2/` (Flutter) · **Depends on:** MOBILE-001 (done) · **Read first:** `docs/tickets/README.md`, `AGENTS.md`, `.agents/rules/*.md`

## Why
The app is going to ETHOnline judges and a remote Ledger tester, and it doesn't look or behave like a usable product yet.

**1. Contrast is broken app-wide.**
- `Chapter2Theme.darkTheme` is `Brightness.dark` with `ColorScheme.dark(surface: white)`, so Material widgets (sheets, dialogs, inputs, switches) render light text on white surfaces.
- Screens mix a dark screen palette (`screenBackground #0D0F12`) with light "card" tokens (`cardSurface #F4F5F7` plus `textPrimary`/`textSecondary`/`textMuted`, which are meant for light cards).
- The result is dark-on-dark and white-on-white text.
- There are also 30+ low-alpha text colors (`withValues(alpha: 0.0–0.4)`), concentrated in `dashboard_screen.dart` and `company_bills_screen.dart`.

**2. There is too much, and much of it is fake.** This violates the zero-fallback rules.
- **Dashboard scenario buttons** (`DashboardCubit.trigger*Scenario`):
  - They propose invented $40/$850 actions to token `0x…41c4e`.
  - They fall back to the Safe address as the agent.
- **Legacy approval sheet:** it sends `'0x_privy_biometric_signature_placeholder'` (`dashboard_screen.dart`, `company_bills_screen.dart`).
- **Bills tab:** the legacy `/vendor/*` rail, with the same placeholder Face ID signing.
- **Settings** hardcodes "Verified Human (Orb)".
- **Onboarding (`onboarding_screen.dart`):**
  - `_verifyWithWorld` waits 1.4 s and invents a random "nullifier hash".
  - `_ledgerPaired = true` and `_faceIdEnabled = true` are hardcoded.
  - The mandate sliders are never saved.
  - It binds the user's **Privy wallet** as the agent address.
  - It falls back to hardcoded Safe/Guard addresses when `/mandates/active` fails (`catch (_) {}`).
  - "Skip" bypasses everything.
- **Dead code:** `MainShellScreen` isn't routed; `DashboardScreen` duplicates the tab bar inside itself.

## Target app (keep it small)

### 1. Single dark theme with real contrast (`lib/shared/theme/`)
Replace the dual palette with one dark palette. Suggested tokens (tune if needed, but keep the contrast rule below):

| Token | Value | Use |
|---|---|---|
| `background` | `#0B0D10` | Scaffold |
| `surface` | `#15181D` | Cards, sheets, nav bar |
| `surfaceRaised` | `#1D2127` | Inputs, list rows |
| `border` | `#2A2F37` | Card and input borders |
| `textPrimary` | `#F2F4F7` | Headings, values |
| `textSecondary` | `#B4BCC8` | Body |
| `textMuted` | `#8A94A3` | Captions, labels (never below this) |
| `primary` | `#7C83FF` | Buttons, links, selected nav |
| `onPrimary` | `#0B0D10` | Text on primary buttons |
| `allow` / `escalate` / `block` | `#32D583` / `#FDB022` / `#F97066` | Verdict text and icons on dark |
| `ledgerOrange` | `#FF7A2E` | Ledger accent |

- **ThemeData:** build a complete `ThemeData` with a `ColorScheme` whose `surface`, `onSurface`, `primary` and `onPrimary` all come from these tokens. Theme the `AppBar`, `Card`, `BottomSheet`, `Dialog`, `InputDecoration`, `ElevatedButton`/`FilledButton`/`TextButton`, `Switch`, `SnackBar`, `NavigationBar` and `Chip` so built-in widgets are readable with no per-widget overrides.
- **Text styles:** `AppTextStyles` must default to `textPrimary` and must never take a color from the old light-card tokens.
- **Contrast rule, enforced by a test:** add `test/theme/contrast_test.dart`, which computes the WCAG contrast ratio of every text token against `background`, `surface` and `surfaceRaised`.
  - `textPrimary` and `textSecondary` must be ≥ 7:1.
  - `textMuted` and the verdict colors must be ≥ 4.5:1.
  - `onPrimary` on `primary` must be ≥ 4.5:1.
- **Migration:** remove the old `cardSurface*`, `actionPill*` and light `text*` tokens and fix every use. Don't use `withValues(alpha: < 0.6)` on text.

### 2. Navigation
- Route the one shell (`MainShellScreen`, or a renamed `HomeShellScreen`) after auth and onboarding. It uses Material 3 `NavigationBar` with three tabs:
  1. **Home**
  2. **Approvals** (the existing `X402ApprovalsScreen`, embedded as a tab, keeping its behavior)
  3. **Activity**
- **Settings** opens from a header icon on Home.
- Remove the duplicate tab bar inside `DashboardScreen`, and remove the **Bills** tab from navigation.

### 3. Home (real data only, with loading/empty/error states for each section)
- **Agent card:** name, `agentAddress` (short, copyable) and status, from `GET /agents` (`AuthCubit.state.agents`). With no agent, show a "Bind your agent" call to action that opens the bind flow from onboarding step 2.
- **Ledger approvals card:** the number of pending escalations from `GET /x402/approvals/pending`, with the first one's amount and resource. Tapping it opens the Approvals tab.
- **Recent activity:** the latest 5 actions from the existing actions API, each with a verdict chip (allow/escalate/block colors on dark). "See all" opens Activity.
- **Remove:**
  - the scenario buttons and their `DashboardCubit` methods;
  - the legacy biometric approval sheet and its placeholder signature;
  - the hero "balance" if it isn't from an API;
  - the bills banner.

### 4. Onboarding: real, three steps, no fake state
Keep `OnboardingScreen` (still routed for `isNewUser`), rebuilt as:

1. **Welcome.** What Chapter 2 does, in three short points:
   - agents pay for APIs with x402;
   - the Guardian decides ALLOW/ESCALATE/BLOCK;
   - big payments are approved on your Ledger.

   Continue button.
2. **Bind your agent.**
   - A text field for the agent wallet address (the address printed by `npm --prefix scripts run agent:address`), validated with `^0x[a-fA-F0-9]{40}$`, plus a name field.
   - Safe and Guard addresses come from `GET /mandates/active`. If that call fails, show the error with Retry and **do not bind**; there are no hardcoded addresses.
   - On success, call `AuthService.bindAgent` and `AuthCubit.refreshAgents()`. On failure, show the backend error inline and stay on the step.
   - **Never** use the user's Privy wallet as the agent address.
3. **Connect your Ledger approver.**
   - Explain Blind signing (Ethereum app settings), then offer **Connect Ledger** using the existing `X402ApprovalsCubit` (scan, connect, address vs `/x402/approvals/config.approverAddress`).
   - Show the device address and whether it matches, from real results only.
   - "Finish" is allowed without connecting, labelled "I'll connect later" and routed to Home. Never show "paired" unless the connect actually succeeded in this session.

**Remove from onboarding:** the World ID step (World hasn't granted Selfie Check access), the Face ID/Ledger toggles, the unsaved mandate sliders, and the top-bar "Skip" (step 3's "I'll connect later" replaces it).

### 5. Settings (real data only)
- **Account:** email/name and wallet from the auth state, shortened and copyable.
- **Backend:** base URL, and the approver address from `/x402/approvals/config`.
- **World ID:**
  - show status from `GET /world/selfie/status/:walletAddress` if that call works;
  - otherwise show "Not configured";
  - never hardcode "Verified".
- **Actions:** sign out and delete account (existing).

### 6. Delete dead UI
Once nothing references them, delete:
- `features/bills/` (screen, cubit, models);
- the legacy `features/approval/` flow and its placeholder sign-off;
- `guardian_analysis_sheet.dart` and `mandate_management_sheet.dart`, if unreferenced after the Home rewrite;
- `MainShellScreen` if it was renamed;
- `ApiService` methods used only by deleted UI.

Update or remove tests that only covered deleted code. Keep `x402_approvals` and its tests intact.

### 7. Screenshot harness, for review (`test/screenshots/`)
- Add widget tests that pump each screen with fake cubits/API data and write PNGs with `matchesGoldenFile`, loading **real fonts** so text is legible:
  - Load Roboto from the Flutter SDK's material fonts cache via `FontLoader`, or bundle an OFL font under `test/fonts/`.
  - Screens: Home (with agent, pending approval, 5 actions), Home empty, Approvals (pending plus connected-matching Ledger), Activity, Settings, Onboarding steps 1–3.
- **Viewport:** 390×844 logical at DPR 3.
- **Command:** `flutter test --update-goldens test/screenshots` generates them into `test/screenshots/goldens/`. Commit the PNGs.
- **Fixtures:** fake data in these test fixtures is fine; it must never appear in runtime code.

## Gates
- `cd chapter2 && flutter analyze` shows no issues.
- `flutter test` passes, including the contrast test and the screenshot tests.
- `flutter build apk --release --split-per-abi --dart-define=BACKEND_BASE_URL=https://chapter2-backend.onrender.com` succeeds.
- Zero-fallback check, which must be empty:

  ```bash
  grep -rnE "placeholder|0x0000000000000000000000000000000000041c4e|Random\(\)|Verified Human|_ledgerPaired|trigger[A-Za-z]*Scenario" lib
  ```

## Commits
- Scope `mobile`, a 1–3 bullet body, **no `Co-Authored-By` trailer**.
- Explicit `chapter2/` paths only. Never push or amend.
- Suggested order:
  1. `feat(mobile): replace the mixed palette with one accessible dark theme`
  2. `refactor(mobile): route one three-tab shell and simplify Home to live data`
  3. `feat(mobile): rebuild onboarding around real agent binding and Ledger connection`
  4. `refactor(mobile): show only live account data in Settings`
  5. `refactor(mobile): remove the legacy bills and placeholder biometric flows`
  6. `test(mobile): add contrast checks and screenshot goldens`

## Acceptance criteria
- **Readable:** every text in the screenshot goldens is readable. The contrast test enforces the ratios.
- **Real:** no screen shows invented balances, verification states, signatures or pairing states.
- **Onboarding:** a new user can bind a real agent address and connect the Ledger approver, or defer the Ledger step.
- **Approvals:** the Approvals tab still passes all MOBILE-001 tests, and the release APK builds.
