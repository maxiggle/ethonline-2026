# Feature Documentation: x402 v2 Seller Endpoints

## 1. Overview
Ticket `X402-001` replaces the homegrown `/vendor/*` `X-Payment-TxHash` scheme with standard
**x402 v2**: the server challenges with `402` and a `PAYMENT-REQUIRED` header, the client retries
with a signed `PAYMENT-SIGNATURE` (EIP-3009 USDC authorization), the public Base Sepolia facilitator
(`https://x402.org/facilitator`) verifies and settles on-chain, and the server confirms with a
`PAYMENT-RESPONSE` header carrying the settlement transaction hash. All three resources return real
data — no fabricated weather, chain state, or USDC figures.

## 2. How It Was Built

### Config (`backend/src/x402/x402.config.ts`)
`loadX402Config()` reads and validates `X402_NETWORK` (must be exactly `eip155:84532`),
`X402_FACILITATOR_URL`, `USDC_ADDRESS`, `X402_PAY_TO_ADDRESS`, `X402_PARTNER_PAY_TO_ADDRESS` and
`PUBLIC_BASE_URL`. It throws immediately on anything missing or malformed — no fallbacks. It is
registered as the `X402_CONFIG` DI token (`x402.module.ts`) via a `useFactory`, so a bad config fails
Nest's provider instantiation at startup, before `app.listen`.

### Middleware (`backend/src/main.ts`)
Before `app.listen`, `main.ts` builds an `x402ResourceServer` (from `@x402/core/server`) backed by
`HTTPFacilitatorClient`, registers `ExactEvmScheme` (from `@x402/evm/exact/server`) for
`eip155:84532`, and wires `@x402/express`'s `paymentMiddleware` with the route table from
`x402.routes.ts`. The SDK syncs with the facilitator (`getSupported()`) as this middleware is set up.

### Resources (`backend/src/x402/x402-resources.{controller,service}.ts`)
No `PrivyAuthGuard` — the verified on-chain payment is the authorization, enforced by the middleware
before these handlers ever run.

| Route | Price | payTo | Data |
|---|---|---|---|
| `GET /x402/weather?city=` | $0.01 | `X402_PAY_TO_ADDRESS` | Real Open-Meteo geocode + current conditions |
| `GET /x402/chain-report` | $2.00 | `X402_PAY_TO_ADDRESS` | Real Base Sepolia latest block, fee data, and live USDC `totalSupply`/`decimals` via a read-only `JsonRpcProvider` |
| `GET /x402/partner-feed` | $0.05 | `X402_PARTNER_PAY_TO_ADDRESS` | Same chain data as chain-report; exists to demo BLOCK in X402-002, since this payee isn't on the approved list |

Weather returns `400` for a missing `city`, `404` when Open-Meteo's geocoder finds nothing, and `502`
for any upstream failure. `chain-report`/`partner-feed` never call `OnChainExecutorService` (its
relayer key is leaked) — they only read from the RPC.

### Discovery (`VendorService.getBazaarCatalog()`)
Rebuilt from `X402_CONFIG` to list exactly these three resources, in v2 `accepts` shape
(`scheme: 'exact'`, `network`, `asset: USDC_ADDRESS`, atomic `amount`, `payTo`). The legacy
AccuWeather/GPU-compute catalog entries are gone from `/discovery/resources` and `/discovery/search`,
but the legacy `/vendor/*` controller routes and their own SEC-004 payment verification are untouched
and still work standalone. `VendorService.invokeService` (used by `/vendor/invoke` and
`/discovery/call`) still only recognizes the old `/vendor/weather` / `/vendor/compute` paths for
settlement, so it now 404s on every catalog entry (old paths aren't listed; new paths have no
settlement handler wired here) — that gap is intentionally left for X402-002/003's own payments API.

## 3. Data Flow & Interfaces
```
Client → GET /x402/weather?city=Lagos (no payment)
Server → 402 + PAYMENT-REQUIRED (base64 PaymentRequired: network, asset, amount, payTo)
Client → GET /x402/weather?city=Lagos + PAYMENT-SIGNATURE (EIP-3009 signed authorization)
@x402/express middleware → facilitator.verify() → handler runs → facilitator.settle() (only if the
  handler responded < 400) → 200 + PAYMENT-RESPONSE (settlement tx hash)
```

## 4. Trade-offs / Edge Cases
- **ts-jest + node16 subpaths:** `tsconfig.json` moved to `module`/`moduleResolution: "node16"` so
  `tsc` resolves the SDK's package.json `exports` subpaths (`@x402/core/server`,
  `@x402/evm/exact/server`). ts-jest's language-service mode can't resolve those same subpaths under
  node16, so `isolatedModules: true` is set at the ts-jest transform level (not in `tsconfig.json`,
  which would conflict with `emitDecoratorMetadata` on this codebase's many NestJS decorated
  constructor/method parameters).
- **Facilitator dependency at startup:** the middleware syncs with the live facilitator when it's
  built. Tests that exercise the real Express pipeline construct their own `x402ResourceServer` with
  a fake `FacilitatorClient` so they never hit the network.
- **Dual payment rails, on purpose:** the legacy `/vendor/*` TreasuryAction-based rail (SEC-004) and
  the new SDK-verified `/x402/*` rail are independent and don't interoperate; `invokeService` is not
  bridged to the new rail here.
- **Verified manually** against the live facilitator and Open-Meteo/RPC (not just mocked tests): a
  local run confirmed a real `402` with a decodable `PAYMENT-REQUIRED` header for both `/x402/weather`
  and `/x402/chain-report`.
