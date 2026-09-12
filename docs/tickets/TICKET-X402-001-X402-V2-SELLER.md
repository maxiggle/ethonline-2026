# TICKET X402-001: x402 v2 Seller Endpoints (Real Payments, Real Data)

**Lane:** B · **Time box:** 1.5 h · **Component:** `backend/` · **Read first:** `docs/tickets/README.md`

## Why
The current `/vendor/*` endpoints use a homegrown `X-Payment-TxHash` scheme and return fabricated data. Judges expect **standard x402 v2**:
- the server returns `402` with a `PAYMENT-REQUIRED` header;
- the client retries with a signed `PAYMENT-SIGNATURE` (EIP-3009 USDC authorization);
- a facilitator verifies and settles the payment, and the server returns `PAYMENT-RESPONSE`.

Base Sepolia (`eip155:84532`) is supported by the public facilitator `https://x402.org/facilitator`.

## Implementation
1. **Install** into `backend` (Node 20 on Render), exact-pinned versions: `@x402/express`, `@x402/core`, `@x402/evm`. Read their READMEs and the official example `x402-foundation/x402/examples/typescript/servers/express`.
2. **Config:** add `backend/src/x402/x402.config.ts` to load and validate the required env: `X402_NETWORK` (must be `eip155:84532`), `X402_FACILITATOR_URL`, `USDC_ADDRESS`, `X402_PAY_TO_ADDRESS`, `X402_PARTNER_PAY_TO_ADDRESS`, `PUBLIC_BASE_URL`. Throw when missing or malformed; no defaults. Update `backend/.env.example` and `render.yaml`, where addresses are values and nothing is a secret.
3. **Wire the payment middleware in `backend/src/main.ts`** (NestJS runs on Express), before `app.listen`. Follow the installed SDK API; the expected shape is:
   ```ts
   import { paymentMiddleware, x402ResourceServer } from '@x402/express';
   import { ExactEvmScheme } from '@x402/evm/exact/server';
   import { HTTPFacilitatorClient } from '@x402/core/server';

   const resourceServer = new x402ResourceServer(new HTTPFacilitatorClient({ url: config.facilitatorUrl }))
     .register(config.network, new ExactEvmScheme());
   app.use(paymentMiddleware(buildX402Routes(config), resourceServer));
   ```
   Put the route table in `backend/src/x402/x402.routes.ts`. Use the SDK's route config format (price, network, payTo, description, mimeType, and discovery/Bazaar metadata if supported):

   | Route | Price | payTo | Handler returns |
   |---|---|---|---|
   | `GET /x402/weather?city=<name>` | `$0.01` | `X402_PAY_TO_ADDRESS` | **Real** current weather from Open-Meteo (no API key): geocode with `https://geocoding-api.open-meteo.com/v1/search?name=<city>&count=1`, then `https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code`. Include `source: "open-meteo.com"`. |
   | `GET /x402/chain-report` | `$2.00` | `X402_PAY_TO_ADDRESS` | **Real** Base Sepolia data read through a read-only `JsonRpcProvider(RPC_URL)`: latest block number and timestamp, `getFeeData()`, and USDC `totalSupply()` / `decimals()`. It is priced above `X402_AUTONOMOUS_LIMIT` so it triggers escalation. |
   | `GET /x402/partner-feed` | `$0.05` | `X402_PARTNER_PAY_TO_ADDRESS` | Same real chain data as above. It exists to demo BLOCK, since this payee isn't approved. |

   **Settlement check:** confirm in the SDK source whether settlement happens only after the handler returns 2xx. If it doesn't, handle errors so the buyer isn't charged for failed responses.
4. **Handlers:** add `backend/src/x402/x402-resources.controller.ts` plus a service in an `X402Module` registered in `AppModule`.
   - **No `PrivyAuthGuard`:** the payment is the authorization.
   - **Weather errors:** return `400` when `city` is missing, `404` when geocoding finds nothing, and `502` when the upstream fails. Never fabricate data.
   - **Read-only RPC:** don't use `OnChainExecutorService`.
5. **Discovery:** update `VendorService.getBazaarCatalog()` so `/discovery/resources` and `/discovery/search` list **only** the three new x402 v2 resources.
   - Build the resource URLs from `PUBLIC_BASE_URL`, with `accepts` in v2 shape: `scheme: 'exact'`, `network`, `asset: USDC_ADDRESS`, `amount` in atomic units, `payTo`.
   - Remove the legacy weather/compute catalog entries. **Leave the legacy `/vendor/*` routes' code in place.**
   - Update the affected vendor specs.
6. **Tests:**
   - Service unit tests for the weather lookup (mock `fetch`): success, city not found → 404, upstream failure → 502, missing city → 400.
   - Chain report with a mocked provider.
   - A test that starts the Nest app with the middleware (`app.listen(0)`) and asserts an unpaid `GET /x402/weather?city=Lagos` returns `402` with a `PAYMENT-REQUIRED` header. Decode it and check the network `eip155:84532`, the USDC asset and `payTo`. If the SDK contacts the facilitator during challenge creation or startup, mock `HTTPFacilitatorClient`.

## Acceptance criteria
- **402 challenge:** `curl -i "$PUBLIC_BASE_URL/x402/weather?city=Lagos"` returns `402` with a decodable v2 `PAYMENT-REQUIRED` header for Base Sepolia USDC and the configured `payTo`.
- **Real paid response:** a paid request (verified end-to-end in X402-003) returns real Open-Meteo data plus a `PAYMENT-RESPONSE` header containing the settlement transaction hash.
- **No invented data:** nothing fabricated in any new handler.
- **Gate:** the backend gate passes.
- **Commits** (for example):
  - `feat(backend): add x402 v2 payment middleware with Base Sepolia facilitator`
  - `feat(backend): serve real weather and chain data as x402 resources`
  - `refactor(backend): list x402 v2 resources in Bazaar discovery`
