# Feature Documentation: Ledger Bluetooth Approvals in the Mobile App

## 1. Overview
When the Guardian escalates an x402 payment, the human approves or rejects it **on their Ledger (Nano X / Flex) over Bluetooth**, from the app's **Approvals** tab. The backend accepts the decision only if its signature recovers to `LEDGER_APPROVER_ADDRESS`. The app never holds the agent's key or the approver's key.

Ticket: [TICKET-MOBILE-001](../tickets/TICKET-MOBILE-001-LEDGER-BLE-X402-APPROVALS.md)

## 2. How It Was Built

### Transport
- **Bluetooth:** `ledger_flutter_plus` 1.6.0+1 handles scanning, connecting and APDU framing. `universal_ble` is pinned to 2.0.0 through `dependency_overrides`, because 2.1.0–2.3.0 break Android release builds.
- **Test seam:** [`ledger_ble_client.dart`](../../chapter2/lib/features/x402_approvals/ledger/ledger_ble_client.dart) wraps the package's sealed `LedgerInterface` so the cubit can be tested with a fake signer.

### Ethereum app operations
These are written by hand from Ledger's `app-ethereum` spec, in [`ledger_ethereum_operations.dart`](../../chapter2/lib/features/x402_approvals/ledger/ledger_ethereum_operations.dart):

| Operation | APDU | Use |
|---|---|---|
| Get address | `E0 02 00 00` + path | Read the device's `44'/60'/0'/0/0` address and compare it to the approver |
| Sign EIP-712 (v0, hashed) | `E0 0C 00 00` + path ‖ domain separator ‖ message hash | Approve the USDC `TransferWithAuthorization` |
| Sign personal message | `E0 08` chunked, P1 `00` then `80` | Sign `chapter2-reject:<actionId>` to reject |

- **Derivation path:** encoded in [`ledger_derivation_path.dart`](../../chapter2/lib/features/x402_approvals/ledger/ledger_derivation_path.dart).
- **Signatures:** assembled as `r ‖ s ‖ v` with v normalized to 27/28 ([`ledger_signature.dart`](../../chapter2/lib/features/x402_approvals/ledger/ledger_signature.dart)).
- **Status words:** mapped to user-facing errors, such as rejected on device, locked, Ethereum app not open, or Blind signing off ([`ledger_status_word.dart`](../../chapter2/lib/features/x402_approvals/ledger/ledger_status_word.dart)).

### EIP-712 hashing
- **Implementation:** [`eip712_hasher.dart`](../../chapter2/lib/features/x402_approvals/eip712/eip712_hasher.dart) computes the domain separator and struct hash with Keccak-256 (`pointycastle` 4.0.0). It derives `EIP712Domain` from the domain keys when the typed data omits it.
- **Verification:** tests compare the domain separator, message hash and final digest against values generated with ethers.

### Approval flow
Implemented in [`x402_approvals_cubit.dart`](../../chapter2/lib/features/x402_approvals/cubit/x402_approvals_cubit.dart):
1. Load `GET /x402/approvals/config`, and poll `GET /x402/approvals/pending` every 3 s while visible.
2. **Connect:** scan, connect, read the address. Approvals are blocked unless the address matches `approverAddress`.
3. **Approve:** refuse if the authorization has expired. Otherwise hash the stored typed data, sign it on the device, and post it to `POST /x402/approvals/:id/signature`.
4. **Reject:** sign `chapter2-reject:<actionId>` on the device, and post it to `POST /x402/approvals/:id/reject`.

The UI is in [`x402_approvals_screen.dart`](../../chapter2/lib/features/x402_approvals/view/x402_approvals_screen.dart). Each pending card shows the resource, amount, payee, agent, risk score, Guardian reasons, expiry countdown, and the Blind signing hint.

### Platform setup
- **Android:** `BLUETOOTH_SCAN` (with `neverForLocation`) and `BLUETOOTH_CONNECT`; legacy Bluetooth and location permissions up to SDK 30. `minSdk` is 28, which `privy_flutter` requires.
- **iOS:** `NSBluetoothAlwaysUsageDescription` and `NSBluetoothPeripheralUsageDescription`.

## 3. Data Flow & Interfaces
```
Approvals tab → GET /x402/approvals/pending                → pending escalations (typedData, reasons, expiry)
User → Connect Ledger → GET ADDRESS                        → must equal /x402/approvals/config.approverAddress
User → Approve → Eip712Hasher(typedData) → SIGN EIP-712 v0 → r‖s‖v
App → POST /x402/approvals/:id/signature                   → backend recovers signer == LEDGER_APPROVER_ADDRESS → SIGNED
Agent worker (polling) receives the signature               → completes the x402 payment from the Ledger address
```

## 4. Trade-offs / Edge Cases
- **Blind signing:** v0 hashed EIP-712 shows hashes on the device, not the amount and payee, so Blind signing must be on. The app shows the details instead. Full clear signing needs a Flutter Ethereum signer; see [ledger-dx-feedback.md](../ledger-dx-feedback.md) item 14.
- **Expiry:** an authorization expires at `validBefore`, up to 15 minutes for `chain-report`. The app and the backend both refuse late approvals.
- **Hardware testing:** Bluetooth pairing and real status-word behavior can only be verified on a device. The unit tests use fakes.
- **Tests:** [`chapter2/test/features/x402_approvals`](../../chapter2/test/features/x402_approvals) covers EIP-712 vectors, APDU encoding and parsing, personal message chunking, status words, and the cubit (approver mismatch, approve, reject, device rejection).
