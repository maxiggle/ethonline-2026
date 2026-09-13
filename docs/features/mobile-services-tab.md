# Feature Documentation: Services Tab (Bazaar Discovery and Agent Purchases)

## 1. Overview
The **Services** tab is where a company operator finds paid x402 services and asks their AI agent to buy one:
1. The app loads the backend's service catalog once, and search filters it instantly on the device.
2. A service detail sheet shows price, payee, inputs and an example response.
3. **Ask agent to pay** creates a purchase request. The agent worker pays it through the Guardian: ALLOW, ESCALATE to the Ledger, or BLOCK.
4. A purchase detail screen follows the request until it's paid, blocked, rejected, expired or failed.

Ticket: [TICKET-MOBILE-003](../tickets/TICKET-MOBILE-003-SERVICES-TAB.md). Backend and worker side: [x402-agent-purchase-requests.md](x402-agent-purchase-requests.md).

## 2. How It Was Built

### Data
- **Catalog entry:** [`bazaar_service.dart`](../../chapter2/lib/features/services/models/bazaar_service.dart) parses a `GET /discovery/resources` item: name, description, tags, method, query parameters with their example values, output example, and the price and payee from the Base Sepolia accept. Items without a Base Sepolia accept are skipped.
- **Purchase request:** [`purchase_request.dart`](../../chapter2/lib/features/services/models/purchase_request.dart) mirrors the backend object and every status.
- **API:** [`services_api_service.dart`](../../chapter2/lib/features/services/remote/services_api_service.dart) calls `GET /discovery/resources`, `POST /x402/purchase-requests`, `GET /x402/purchase-requests` and `GET /x402/purchase-requests/:id`. The purchase routes use the Privy Bearer token.

### State
[`services_cubit.dart`](../../chapter2/lib/features/services/cubit/services_cubit.dart) and [`services_state.dart`](../../chapter2/lib/features/services/cubit/services_state.dart):
- **Catalog:** fetched once, with loading, error and Retry states, plus pull to refresh.
- **Search:** only stores the query. The filtered list is computed in memory over the fetched catalog (name, description, tags, resource path, case-insensitive), so typing never calls the network.
- **Purchases:** polled every 3 s while the tab is visible.

### Screens
- **List:** [`services_screen.dart`](../../chapter2/lib/features/services/view/services_screen.dart) shows the search field, service cards (name, description, tags, price, network) and **Your purchases**.
- **Detail sheet:** [`service_detail_sheet.dart`](../../chapter2/lib/features/services/view/service_detail_sheet.dart) shows details, an input field per query parameter prefilled with the catalog example, an agent picker (only `ACTIVE` agents), a justification, and **Ask agent to pay**. Without an agent, it links to binding one.
- **Purchase detail:** [`purchase_detail_screen.dart`](../../chapter2/lib/features/services/view/purchase_detail_screen.dart), with status text from [`purchase_status_presenter.dart`](../../chapter2/lib/features/services/utils/purchase_status_presenter.dart), polls every 3 s until a terminal status.

| Status | Shown |
|---|---|
| `QUEUED` | Waiting for the agent; after 30 s, a hint to start the worker |
| `PROCESSING` | Agent is requesting payment terms |
| `AUTHORIZED` + `ALLOW` | Guardian allowed it; agent is paying |
| `AUTHORIZED` + `ESCALATE` | Needs your Ledger approval, with the reasons and an **Open Approvals** button |
| `PAID` | Transaction hash (copyable), Blockscout link (copyable), and the service response as key/value rows |
| `BLOCKED` | The Guardian's reasons |
| `REJECTED` / `EXPIRED` / `FAILED` | The error |

## 3. Data Flow & Interfaces
```
Services tab → GET /discovery/resources          → catalog (once)
Search field → in-memory filter                    → no network calls
Detail sheet → POST /x402/purchase-requests       → QUEUED
Agent worker → claim → Guardian → pay → report    → PROCESSING → AUTHORIZED → PAID / BLOCKED / …
Purchase detail → GET /x402/purchase-requests/:id  → status timeline (every 3 s)
```

## 4. Trade-offs / Edge Cases
- **Queued until the worker runs:** the app can't pay by itself, because the agent's key lives only on the agent machine. The QUEUED hint points to the worker.
- **One request at a time:** the worker processes requests in order, so an escalated request waiting for the Ledger delays later requests until it's approved or expires.
- **Blockscout link:** copied instead of opened, because `url_launcher` isn't a dependency.
- **Tests:** [`chapter2/test/features/services`](../../chapter2/test/features/services) covers model parsing, every status, local search with no extra API calls, the error then Retry path, and purchase creation. Screenshot tests cover the list, search, detail, paid and escalated screens.
