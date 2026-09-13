# TICKET MOBILE-001: Approve Escalated x402 Payments on a Ledger over Bluetooth (Android APK)

**Time box:** 3 h · **Component:** `chapter2/` (Flutter, Android) · **Depends on:** X402-002 API (done, unchanged) · **Read first:** `docs/tickets/README.md`

## Why
- **Who tests:** the Ledger (Nano X or Flex) is with a remote tester who installs an APK.
- **What the APK does:** escalated x402 payments show up in the Chapter 2 app, and the human approves or rejects each one **on the Ledger over Bluetooth**.
- **Backend authority:** the backend accepts a decision only if its signature recovers to `LEDGER_APPROVER_ADDRESS`.
- **Relation to the web console:** this replaces the web approval console for the demo. The console stays in the repo as an alternative.

**Out of scope:**
- **World ID Selfie Check:** blocked on World granting access; a later ticket.
- **Legacy flows:** `/actions/*` approval and Privy signing stay as they are. Do not wire this feature into them.

## Backend contract (already live; do not change the backend)
All routes are public reads plus Ledger-signature-gated writes. Base URL: `AppConfig.backendBaseUrl`.

| Call | Response / body |
|---|---|
| `GET /x402/approvals/config` | `{ approverAddress, network, usdcAddress }` |
| `GET /x402/approvals/pending` | `[{ actionId, resourceUrl, amount, payTo, agentAddress, justification, riskScore, reasons: string[], typedData, createdAt }]` |
| `POST /x402/approvals/:actionId/signature` | body `{ signature }`: 65-byte `0x` r‖s‖v EIP-712 signature over `typedData` |
| `POST /x402/approvals/:actionId/reject` | body `{ signature }`: EIP-191 personal_sign of the UTF-8 string `chapter2-reject:<actionId>` |

**`typedData` shape** (EIP-3009, produced by the x402 SDK; numbers may arrive as strings):
```json
{
  "domain": { "name": "USDC", "version": "2", "chainId": 84532, "verifyingContract": "0x036C…CF7e" },
  "types": { "TransferWithAuthorization": [
    {"name":"from","type":"address"}, {"name":"to","type":"address"}, {"name":"value","type":"uint256"},
    {"name":"validAfter","type":"uint256"}, {"name":"validBefore","type":"uint256"}, {"name":"nonce","type":"bytes32"}
  ]},
  "primaryType": "TransferWithAuthorization",
  "message": { "from": "0x…", "to": "0x…", "value": "2000000", "validAfter": "0", "validBefore": "1789000000", "nonce": "0x…32 bytes" }
}
```
- **Missing `EIP712Domain`:** `types` may omit it. Derive it from the keys present in `domain`, in the canonical order `name`, `version`, `chainId`, `verifyingContract`, `salt`.
- **Expiry:** the backend returns `400` once `message.validBefore` has passed.

## Implementation

### 1. Dependencies and Android setup
- **`ledger_flutter_plus`:** add it at an exact pinned version (`flutter pub add ledger_flutter_plus`, then pin). It provides BLE scanning, connection, and `sendOperation` with custom `LedgerOperation<T>` (`write(ByteDataWriter, index, mtu)` / `read(ByteDataReader, index, mtu)`). Read the installed package's source for the exact API and for how it frames APDUs and status words.
- **Keccak-256:** use a pinned, maintained package such as `pointycastle`'s `KeccakDigest(256)` or `web3dart`. Do not hand-roll it.
- **Manifest** (`android/app/src/main/AndroidManifest.xml`):
  - `INTERNET`;
  - `BLUETOOTH_SCAN` with `android:usesPermissionFlags="neverForLocation"`;
  - `BLUETOOTH_CONNECT`;
  - `ACCESS_FINE_LOCATION` with `android:maxSdkVersion="30"`;
  - legacy `BLUETOOTH` / `BLUETOOTH_ADMIN` with `android:maxSdkVersion="30"`.
- **Runtime permissions:** request them through the package's `onPermissionRequest` hook, or `permission_handler` (pinned) if the package requires it.
- **`minSdk`:** raise it in `android/app/build.gradle.kts` only if a dependency requires it.

### 2. Ledger Ethereum operations (`lib/features/x402_approvals/ledger/`)
The derivation path is fixed: `44'/60'/0'/0/0`. It is encoded as 1 byte count `05`, then five 4-byte big-endian indexes. Hardened indexes are OR'd with `0x80000000`: `8000002C 8000003C 80000000 00000000 00000000`.

**Get address:** CLA `E0`, INS `02`, P1 `00`, P2 `00`, data = path.
- The response is pubkey length (1 byte), the pubkey, address length (1 byte), then the ASCII hex address without `0x`.
- Return a checksummed `0x` address.

**Sign EIP-712, v0 hashed:** CLA `E0`, INS `0C`, P1 `00`, P2 `00`, data = path ‖ domainSeparator (32 bytes) ‖ hashStruct(message) (32 bytes).
- The response is `v` (1 byte), `r` (32 bytes), `s` (32 bytes).

**Sign personal message:** CLA `E0`, INS `08`, P2 `00`.
- The first block has P1 `00`, and data = path ‖ message length (4 bytes big-endian) ‖ first chunk.
- Subsequent blocks have P1 `80`, and data = the next chunk.
- Chunks are at most 255 bytes of APDU data in total. The response is `v`, `r`, `s`.

**Signature assembly:**
- The output is `0x` ‖ r (left-padded to 32 bytes) ‖ s (left-padded to 32 bytes) ‖ v.
- If the device returns v as 0 or 1, add 27. v must end as 27 or 28.

**Status words → user-facing errors:**
| Status word | Message |
|---|---|
| `6985` | Rejected on the Ledger |
| `5515` / `6982` | Unlock the Ledger |
| `6D00` / `6E00` / `6511` | Open the Ethereum app |
| `6A80` | Enable Blind signing in the Ethereum app settings |

Map anything else to a generic error that includes the hex status word.

### 3. EIP-712 hashing (`lib/features/x402_approvals/eip712/`)
Implement `hashStruct` / `encodeType` / `encodeData` for the types used here: `string`, `uint256`, `address` and `bytes32`, plus a generic struct walk.
- `domainSeparator = hashStruct('EIP712Domain', domain)`.
- `messageHash = hashStruct(primaryType, message)`.
- Accept numeric fields given as either strings or numbers.

**Test vector (mandatory).** Generate expected values with ethers from the backend's installed dependencies, for a fixed typed-data example:

```bash
cd backend && node -e "const {TypedDataEncoder,Wallet}=require('ethers'); /* build domain/types/message, print TypedDataEncoder.hashDomain, hashStruct, hash, and a Wallet(fixedTestKey).signTypedData signature */"
```

- Hardcode those expected hashes in `test/` (test fixtures only, never runtime).
- Assert that the Dart domain separator, message hash and final digest `keccak256(0x1901 ‖ domainSeparator ‖ messageHash)` all match.

### 4. Feature: `lib/features/x402_approvals/`
**API service** with the four calls above, reusing the app's `ApiClient`/Dio. There is no auth header, because these routes are public.

**`X402ApprovalsCubit`:**
- Loads the config.
- Polls `pending` every 3 s while the screen is visible, and stops polling when it closes.
- `connectLedger(device)` connects, reads the address, and checks it against `approverAddress`.
  - On a mismatch it shows a blocking error: "This Ledger (0x…) is not the configured approver (0x…)". It also displays the device address so the tester can send it to the backend owner.
- `approve(actionId)` computes the hashes, signs on the device, and posts the signature.
- `reject(actionId)` personal-signs `chapter2-reject:<actionId>` and posts it.
- **States:** idle, connecting, connected(address, matchesApprover), awaitingDevice(actionId, "Confirm on your Ledger"), success, failure(message).

**Screen (`@RoutePage`), registered in `lib/router/app_router.dart`, with regenerated routes (`dart run build_runner build --delete-conflicting-outputs`):**
- A **Connect Ledger** button that scans, lists nearby devices, and connects to the one tapped.
- A connected-device address banner.
- Pending cards showing:
  - resource URL;
  - amount in USDC (6 decimals);
  - payee;
  - agent;
  - risk score;
  - every policy reason;
  - expiry countdown from `validBefore`;
  - **Approve** and **Reject** buttons.
- Disable the buttons when the Ledger isn't connected or doesn't match, or when the payment has expired.
- Before approving, show the hint "On the Ledger you will see the domain and message hashes; Blind signing must be enabled in the Ethereum app."

**Entry point:** a clearly visible "Ledger approvals" entry on the dashboard.

**Rules:**
- **Zero fallback:** no placeholder signatures, addresses or amounts. Everything shown comes from the API or the device.
- **Legacy dashboard flow:** don't touch `approveWithPrivyBiometrics` and its `'0x_privy_biometric_signature_placeholder'` call. List it in your report as a known zero-fallback violation outside this ticket's scope.

### 5. Tests
- **EIP-712:** the ethers vectors from step 3.
- **APDU encoding:**
  - path bytes;
  - the EIP-712 v0 data layout (length 1 + 20 + 32 + 32);
  - personal-message chunking for a message longer than 255 bytes;
  - response parsing for address and v/r/s, including the v 0/1 → 27/28 normalization.
- **Status-word mapping.**
- **Cubit** (`bloc_test` if already present, otherwise plain tests), with a fake API and a fake signer:
  - approver mismatch blocks approval;
  - approve posts the assembled signature;
  - reject posts the personal-sign signature;
  - device rejection surfaces the mapped error.

## Gates
- `cd chapter2 && flutter analyze && flutter test` must pass, with no new analyzer issues (the baseline is clean).
- `cd chapter2 && flutter build apk --release --dart-define=BACKEND_BASE_URL=https://chapter2-backend.onrender.com` must succeed. Report the APK path and size.
- Real BLE signing cannot be tested without the device. Say so in the report instead of claiming it works.

## Commits
- Scope `mobile`, a 1–3 bullet body, **no `Co-Authored-By` trailer**.
- Stage explicit paths under `chapter2/` only. Never push or amend.
- Suggested commits:
  - `feat(mobile): add Ledger BLE Ethereum operations and EIP-712 hashing`
  - `feat(mobile): approve and reject escalated x402 payments on a Ledger`
  - `test(mobile): cover EIP-712 vectors, APDU encoding and approval flow`
  - `build(mobile): add Bluetooth permissions for Ledger approvals`

## Acceptance criteria
- **Tester flow:** a tester with the APK and a Nano X / Flex can:
  1. connect over Bluetooth;
  2. see a pending escalation with its real reasons;
  3. approve it with a signature the backend accepts (`SIGNED`), or reject it (`REJECTED`).
- **Hashing:** the EIP-712 test vectors match ethers exactly.
- **Build:** the release APK builds.
