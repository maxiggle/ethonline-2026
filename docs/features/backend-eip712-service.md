# Feature Documentation: Backend EIP-712 Service

## 1. Overview
The **Backend EIP-712 Service** (`Eip712Service`) is the cryptographic bridge between backend supervisory decisions and on-chain escalation enforcement in [Chapter2Guard.sol](file:///Users/godwinekainu/.gemini/antigravity-ide/scratch/ethonline-2026/contracts/src/Chapter2Guard.sol). When an autonomous AI proposal exceeds autonomous caps ($100 per action or $500 daily budget) or triggers elevated risk from the Asymmetric AI Guardian, it cannot be executed without typed cryptographic authorization from the authorized human owner/hardware key.

The service handles:
1. Constructing compliant EIP-712 typed data payloads for hardware wallets (Ledger) and mobile Secure Enclaves.
2. Computing the exact 32-byte domain separator, struct hash, and signing digest matching `Chapter2Guard`.
3. Validating signatures and verifying that the recovered signer matches the authorized `humanSigner`.
4. ABI encoding the escalated payload `abi.encode(TreasuryActionApproval, bytes sig)` for Gnosis Safe `execTransaction()`.

---

## 2. Cryptographic Specifications

### A. EIP-712 Domain Separator
```typescript
{
  name: 'Chapter2',
  version: '1',
  chainId: 84532, // Base Sepolia
  verifyingContract: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3'
}
```

### B. Typehash & Struct Definition
* **Type String**:
  `TreasuryActionApproval(string actionId,address agent,address recipient,address token,uint256 amount,uint256 nonce,uint256 deadline,bytes32 mandateHash,uint8 riskScore)`
* **Typehash**:
  `keccak256("TreasuryActionApproval(string actionId,address agent,address recipient,address token,uint256 amount,uint256 nonce,uint256 deadline,bytes32 mandateHash,uint8 riskScore)")`

### C. Safe Execution ABI Encoding
Escalated transactions submitted through `Safe.execTransaction(...)` pass the approval parameters and signature packed into the `signatures` argument:
```typescript
AbiCoder.defaultAbiCoder().encode(
  [
    'tuple(string actionId, address agent, address recipient, address token, uint256 amount, uint256 nonce, uint256 deadline, bytes32 mandateHash, uint8 riskScore)',
    'bytes'
  ],
  [tupleValues, signatureHex]
);
```

---

## 3. Test Coverage Matrix (11 / 11 Tests Passing)

| Test Suite | File | Tests Passing | Scenarios Covered |
| :--- | :--- | :--- | :--- |
| **EIP-712 Service** | `eip712.service.spec.ts` | 11 / 11 | Domain separator parity with Base Sepolia contract.<br>Typehash conformance to `Chapter2Guard`.<br>Typed data envelope generation.<br>Digest computation parity.<br>Signature signing and verification with `ethers.Wallet`.<br>Address recovery from 65-byte signature.<br>Rejection of unauthorized signers.<br>Rejection on parameter tampering (amount, recipient, nonce, riskScore).<br>ABI encoding and decoding of escalated execution payloads.<br>Cross-verification with Foundry test vector (`0xA11CE` from `Chapter2Guard.t.sol`). |

---

## 4. Verification Commands

```bash
# Run unit tests for Eip712Service
cd backend && npm test -- eip712.service.spec.ts

# Run all backend test suites (33 tests)
cd backend && npm test

# Run build compilation check
cd backend && npm run build
```
