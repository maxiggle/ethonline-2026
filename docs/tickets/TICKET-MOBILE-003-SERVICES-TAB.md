# TICKET MOBILE-003: Services Tab (Bazaar Discovery, Search, Ask Agent to Pay)

**Time box:** 2.5 h · **Component:** `chapter2/` · **Depends on:** MOBILE-002 (done), X402-004 API contract (being built in parallel; code against the contract) · **Read first:** `docs/tickets/README.md`, `docs/tickets/TICKET-X402-004-AGENT-PURCHASE-REQUESTS.md` (API contract section), `AGENTS.md`, `.agents/rules/*.md`

## Why
The app helps companies pay for services:
1. The operator browses x402 services.
2. They pick one.
3. They ask their AI agent to pay for it.
4. The Guardian decides ALLOW / ESCALATE (Ledger) / BLOCK.
5. The operator sees the result: status, transaction, and the data the service returned.

## Data sources (real only)

### Catalog: `GET /discovery/resources` (public)
The live response looks like this:
```json
{ "items": [ {
  "resource": "https://chapter2-backend.onrender.com/x402/weather",
  "type": "http", "x402Version": 2,
  "accepts": [ { "network": "eip155:84532", "asset": "0x036C…", "amount": "10000", "payTo": "0x…", "scheme": "exact" } ],
  "extensions": { "bazaar": { "info": {
    "serviceName": "Open-Meteo Weather Oracle",
    "description": "Real-time weather telemetry from Open-Meteo for a given city",
    "tags": ["weather","climate","oracle","open-meteo"],
    "input": { "type": "http", "method": "GET", "queryParams": { "city": "Lagos" } },
    "output": { "type": "json", "example": { "city": "Lagos", "temperatureC": 29.4 } }
  } } }
} ], "pagination": { } }
```

### Purchase requests (`PrivyAuth`; the app already sends the Privy bearer token)
- `POST /x402/purchase-requests`
- `GET /x402/purchase-requests`
- `GET /x402/purchase-requests/:id`

The object shape and statuses are defined exactly in X402-004.

### Agents
Agents come from `AuthCubit.state.agents` (`GET /agents`).

## Implementation (`lib/features/services/`)

### 1. Navigation
Add a fourth `NavigationDestination`, **Services** (storefront or apps icon), in `lib/features/shell/main_shell_screen.dart`. The tabs become Home, Services, Approvals, Activity. Keep the MOBILE-002 theme tokens; don't add new colors unless a contrast test covers them.

### 2. Models and API
- **`BazaarService`**, parsed from a catalog item:
  - `resourceUrl`, `serviceName`, `description`, `tags`, `method`;
  - `queryParams` (a map of name → example value from the catalog);
  - `outputExample`;
  - `priceAtomic`, `payTo` and `network`, taken from the first accept with `network == 'eip155:84532'`.
  - Skip, and don't show, items with no such accept.
- **`PurchaseRequest`**, matching the X402-004 object.
- **`ServicesApiService`:**
  - `fetchCatalog()`
  - `createPurchaseRequest({agentAddress, resourceUrl, queryParams, justification})`
  - `fetchPurchaseRequests()`
  - `fetchPurchaseRequest(id)`

### 3. `ServicesCubit`
- **Catalog load:** fetch once when the tab first opens, with loading, error and Retry states. Pull-to-refresh re-fetches.
- **Search:** filters the already-fetched list on every keystroke, case-insensitive, matching `serviceName`, `description`, `tags` and the resource path. There is no network call per keystroke. Keep the query in state, so an empty result shows "No services match "<query>"" with a clear button.
- **Purchases:** poll `fetchPurchaseRequests()` every 3 s while the tab is visible. Stop polling when the tab is hidden, the same approach as the Approvals polling.

### 4. Services screen
- **Search field** at the top: filled style, clear button, hint "Search services".
- **Service cards:**
  - name, a one-line description, up to 3 tag chips;
  - price as money via `UsdcAmountFormatter`, e.g. `$0.01`;
  - a short network label ("Base Sepolia").
  - Tapping a card opens the detail sheet.
- **"Your purchases" section,** below or as a segmented toggle: the latest purchase requests, showing service name, amount, a status chip and relative time. Tapping one opens the purchase detail.

### 5. Service detail sheet (`showModalBottomSheet`, theme surfaces)
- **Details:** name, full description, tags, price, payee (short and copyable), network, method + resource path, and the output example rendered as key/value rows.
- **Inputs:**
  - one `TextField` per `queryParams` key, prefilled with the catalog's example value;
  - an agent picker from `AuthCubit.state.agents`, where only an `ACTIVE` agent is selectable. With no agents, show "Bind an agent first", linking to the Home bind CTA, and disable paying;
  - a justification field prefilled with `Purchase <serviceName> for <company use>` for the user to edit; required, at most 280 characters.
- **Primary button "Ask agent to pay"** calls `createPurchaseRequest`.
  - On success, close the sheet, show a SnackBar "Sent to <agent name>", and open the purchase detail.
  - On failure, show the backend error inline and keep the sheet open.

### 6. Purchase detail screen or sheet
Poll `fetchPurchaseRequest(id)` every 3 s until the status is terminal. Show a vertical status timeline:

| Status | What to show |
|---|---|
| `QUEUED` | "Waiting for your agent to pick this up." If still `QUEUED` after 30 s, add the hint: "Is the agent worker running? `npm --prefix scripts run agent:worker`" |
| `PROCESSING` | "Agent is requesting payment terms…" |
| `AUTHORIZED` + `ALLOW` | "Guardian allowed it. The agent is paying…" |
| `AUTHORIZED` + `ESCALATE` | "Needs your Ledger approval", with the reasons and a button to the **Approvals** tab |
| `PAID` | Transaction hash (short, copyable), an "View on Blockscout" row (`https://base-sepolia.blockscout.com/tx/<hash>`, opened with `url_launcher` if it's already a dependency, otherwise a copy action) and the `response` JSON rendered as readable key/value rows |
| `BLOCKED` | The Guardian's reasons, in block color |
| `REJECTED` / `EXPIRED` / `FAILED` | The `error` text |

### 7. Tests
- **Model parsing:** the live-shaped catalog item above, an item without a Base Sepolia accept (skipped), and every purchase request status.
- **`ServicesCubit`:**
  - the catalog loads once;
  - search filters locally by name, tag and description, with no extra API calls;
  - empty-result state;
  - the error then Retry path;
  - purchase creation success and failure.
- **Screenshot goldens** (extend `test/screenshots/`, same real-font harness and 390×844 viewport):
  - `services_list.png` (3 services);
  - `services_search_weather.png` (query "weather", 1 result);
  - `services_detail_weather.png` (city field, agent picker, price);
  - `purchase_paid.png` (paid with tx hash and weather data);
  - `purchase_escalated.png`.

## Gates
- `cd chapter2 && flutter analyze` shows no issues.
- `flutter test` passes, including the goldens.
- Zero-fallback check: `grep -rnE "placeholder|Random\(\)|0x0000000000000000000000000000000000041c4e" lib` is empty.
- No APK build is needed; the user runs the app from VS Code.

## Commits
- Scope `mobile`, a 1–3 bullet body, **no `Co-Authored-By` trailer**.
- Explicit `chapter2/` paths only; don't stage `chapter2/ios/Podfile.lock`. Never push or amend.

## Acceptance criteria
- **Browse and search:** the Services tab shows the live catalog, and search filters it instantly.
- **Buy:** an operator with a bound agent can create a purchase request and watch it move to `PAID` (tx and weather data), `AUTHORIZED`/ESCALATE (linking to Approvals) or `BLOCKED`, as the X402-004 worker processes it.
- **Real data only:** everything shown comes from the API.
