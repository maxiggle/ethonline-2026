# Feature Documentation Index

Chapter 2 changed architecture during the hackathon. The original design executed payments from a Safe through a backend relayer. The current product uses x402 agent payments, the Guardian, Ledger approvals and a key-less backend. This index labels each document so readers know what reflects the current system.

Start with [ARCHITECTURE.md](../ARCHITECTURE.md).

## Current

| Document | Covers |
|---|---|
| [x402-v2-seller.md](x402-v2-seller.md) | Paid x402 v2 resources and Bazaar discovery |
| [x402-guardian-payments-api.md](x402-guardian-payments-api.md) | Guardian spending policy, payments API, Ledger-signed approvals |
| [x402-ledger-agent-payments.md](x402-ledger-agent-payments.md) | End-to-end x402 + Ledger payments, Key Ring agent wallet |
| [x402-agent-purchase-requests.md](x402-agent-purchase-requests.md) | App purchase requests and the agent worker |
| [mobile-services-tab.md](mobile-services-tab.md) | Services tab: discovery, search, purchases |
| [mobile-ledger-bluetooth-approvals.md](mobile-ledger-bluetooth-approvals.md) | Ledger approvals over Bluetooth in the app |
| [mobile-ui-and-onboarding.md](mobile-ui-and-onboarding.md) | Theme, navigation, onboarding, Settings |
| [render-backend-deployment.md](render-backend-deployment.md) | Render deployment |
| [backend-world-selfie.md](backend-world-selfie.md) | World ID verification service (see the note at the top) |
| [backend-privy-auth.md](backend-privy-auth.md) | Privy authentication (partly outdated; see the note at the top) |

Also current:
- [development.md](../development.md)
- [world-id-approval-gate.md](../world-id-approval-gate.md)
- [ledger-dx-feedback.md](../ledger-dx-feedback.md)
- Partner pages: [docs/partners](../partners)

## Legacy

These describe the original Safe / `Chapter2Guard` relayer design or unused prototypes. The backend no longer holds a relayer key, so that path never broadcasts transactions.

| Document | Status |
|---|---|
| [agent-deployment-and-endpoint-testing.md](agent-deployment-and-endpoint-testing.md) | Legacy `/actions` relayer flow |
| [backend-api-gateway.md](backend-api-gateway.md) | Legacy actions API and events |
| [backend-eip712-service.md](backend-eip712-service.md) | `Chapter2Guard` EIP-712 approvals |
| [backend-guardian-orchestrator.md](backend-guardian-orchestrator.md) | Legacy orchestrator; its semantic risk analysis is reused by the x402 spending policy |
| [backend-integration-tests.md](backend-integration-tests.md) | Legacy lifecycle e2e suite |
| [backend-ledger-service.md](backend-ledger-service.md) | Backend Ledger signing service for the legacy path |
| [backend-onchain-persistence-x402.md](backend-onchain-persistence-x402.md) | Persistence still applies; the relayer and `/vendor/*` rail are legacy |
| [contracts-chapter2-guard.md](contracts-chapter2-guard.md) | `Chapter2Guard` contracts (read-only today) |
| [mobile-scaffolding.md](mobile-scaffolding.md) | Original app scaffold, superseded |
| [native-security-packages.md](native-security-packages.md) | Native prototypes, not used by the app |
