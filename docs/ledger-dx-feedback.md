# Ledger Developer Experience Feedback

Friction we actually hit while building Chapter 2's agent payment flow with `wallet-cli ring` (Ledger Key Ring) and the Device Management Kit (DMK) over WebHID.

**Versions:**

| Tool | Version |
|---|---|
| `@ledgerhq/wallet-cli` | 2.1.0 |
| `@ledgerhq/device-management-kit` | 1.9.0 |
| `@ledgerhq/device-signer-kit-ethereum` | 1.18.0 |
| `@ledgerhq/device-transport-kit-web-hid` | 1.2.4 |

Each item gives the problem, its impact and a suggested fix. Nothing here is hypothetical: every item comes from our code or from CLI output we captured.

## `wallet-cli ring`

### 1. Unclear stdout contract when a script consumes `ring decrypt`
- **Problem:**
  - `ring decrypt` is documented as "text via stdin/stdout", with `--output human` as the default.
  - When stdout isn't a TTY, `wallet-cli ring decrypt --help` prints a JSON envelope (`{ "ok": true, "data": { … } }`), even when `--output human` is passed explicitly.
  - So we couldn't tell from the docs whether a spawned `ring decrypt` prints the raw plaintext, a human-formatted line, or an envelope.
- **Impact:**
  - The agent's key loader (`scripts/lib/ledger-key-ring.ts`) parses stdout as a 32-byte hex key.
  - If the format differs, the only symptom is our own "did not return a 32-byte private key" error.
  - We had to plan a live check (`npm --prefix scripts run agent:address`) before trusting the integration.
- **Suggested fix:**
  - Document the exact stdout bytes for `ring decrypt` in human mode without `-o` (raw plaintext, no trailing newline or decoration).
  - Make `--help` honour `--output human`.
  - Consider a `--raw` flag that guarantees plaintext-only stdout for scripts.

### 2. No scripted password input besides an environment variable
- **Problem:**
  - `ring encrypt --help` and `ring decrypt --help` list only `--key`, `--input`/`-i`, `--out`/`-o` and `--output`.
  - `ring init` offers `--unsecure-no-password` but no way to pass the password.
  - For non-interactive use (an agent process), our integration supplies the password through `WALLET_PASS`. The CLI documents no stdin or file-descriptor option.
- **Impact:**
  - Integrators have to invent their own secret handling. We document `WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w)` inline on every command so the password never lands in shell history or `.env` files.
  - Every child process of the agent inherits `WALLET_PASS` unless the integrator scrubs it.
- **Suggested fix:** support `--pass-stdin` or a `--pass-fd`, and/or native macOS Keychain / libsecret lookup. Document the recommended pattern for long-running agents.

### 3. First-run agent nudge on stderr
- **Problem:** the first command (including `--help`) printed `Tip: install the Ledger wallet-cli skill so Claude Code can drive this CLI` to stderr. The opt-out (`WALLET_CLI_NO_NUDGE=1`) is only mentioned in the README and CHANGELOG.
- **Impact:** tools that wrap `wallet-cli` and surface stderr in their error messages (ours does, so users see why a decrypt failed) can show this unrelated tip in place of, or next to, the real error.
- **Suggested fix:** don't nudge when stdout/stderr isn't a TTY, and list `WALLET_CLI_NO_NUDGE` in `--help`.

## Device Management Kit / Ethereum signer (web approval console)

### 4. Signatures come back as `{ r, s, v }`, not a 65-byte hex string
- **Problem:** `signTypedData` and `signMessage` return a signature object. Every EVM verifier we feed (ethers `verifyTypedData`/`verifyMessage` on the backend, the x402 facilitator) expects `0x` + r‖s‖v.
- **Impact:**
  - We wrote and tested our own assembly: `approval-console/src/signature.ts` left-pads r and s to 32 bytes and normalizes `v`, accepting both 0/1 and 27/28 because we couldn't rely on one convention.
  - A wrong `v` fails silently: verification simply recovers a different address.
- **Suggested fix:** return (or add a helper for) the serialized 65-byte signature, and document the `v` convention.

### 5. `EIP712Domain` must be present in `types`
- **Problem:** typed data built by viem, ethers and the x402 SDK omits `types.EIP712Domain`, which is standard in those libraries. The signer needed it, so the console reconstructs the field list from whichever domain keys are present (`withEip712DomainType`).
- **Impact:** extra code on a security-critical path. Getting the field order or types wrong changes the domain separator and makes the signature unverifiable.
- **Suggested fix:** derive `EIP712Domain` from `domain` when it's missing, as viem does, or reject the payload with an explicit error that names the missing type.

### 6. Device actions are observables with intermediate states
- **Problem:** `signTypedData`, `signMessage` and `getAddress` return an observable device action (pending, user interaction required, completed, error), not a promise.
- **Impact:** we wrote an `awaitDeviceAction` wrapper on `rxjs` to turn these into promises while surfacing "confirm on your device" prompts. This boilerplate is the same for every dApp.
- **Suggested fix:** ship a documented promise helper, e.g. `await toPromise(action, { onInteraction })`, alongside the observable API.

### 7. Error tags need a user-facing mapping
- **Problem:** failures arrive as `DmkError` values distinguished by `_tag`. We mapped 13 tags to user-facing messages, including:
  - `DeviceLockedError`
  - `RefusedByUserDAError`
  - `UnsupportedApplicationDAError`
  - `NoAccessibleDeviceError`
  - `TransportNotSupportedError`
  - several disconnect variants
- **Impact:** we found the list by reading type definitions. An unmapped tag gives the approver a generic failure at the worst moment.
- **Suggested fix:** publish a table of tags with recommended user-facing copy, or expose a localized `userMessage`.

### 8. `originToken` for partner transaction checks
- **Problem:** `SignerEthBuilder` accepts an optional `originToken`. Without one, Ledger-side transaction checks are reduced, and we found no self-serve way to get a token during the hackathon.
- **Impact:** the console runs without a token and shows a warning banner. We refused to invent a value, so judges and users see reduced checks for the payment the human is approving.
- **Suggested fix:** add a self-serve or testnet origin token for builders, and document exactly which checks are lost without one.

### 9. WebHID constraints
- **Problem:** WebHID is only available in Chromium browsers (Chrome/Edge), in a secure context, and discovery must start from a user gesture.
- **Impact:** the console needs an explicit **Connect Ledger** button plus a "WebHID is not supported" banner. Safari and Firefox users can't approve payments at all.
- **Suggested fix:** a first-party compatibility matrix in the DMK docs, and a documented fallback transport for non-Chromium browsers (e.g. a bridge or mobile BLE handoff).

## x402 SDK (for Ledger-signed x402 payments)

### 10. `paymentRequirementsSelector` in `registerExactEvmScheme` config is silently ignored
- **Problem:**
  - `@x402/evm@2.25.0` declares `EvmClientConfig.paymentRequirementsSelector` in its types.
  - `registerExactEvmScheme`'s implementation never reads it; only `policies` is wired.
  - The selector only takes effect when passed to `new x402Client(selector)`.
- **Impact:** we pay with a remote Ledger signer, so a deterministic choice of which requirement gets signed is security-relevant. A config that type-checks but does nothing could sign a different requirement than the one the Guardian authorized. We had to pass the selector to the client constructor and re-check the choice ourselves.
- **Suggested fix:** wire the option through or remove it from the type, and show the selector on the client constructor in the quick-start.
