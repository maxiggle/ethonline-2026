import 'package:chapter2/features/x402_approvals/eip712/eip712_hasher.dart';
import 'package:chapter2/features/x402_approvals/eip712/eip712_typed_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test vector generated with ethers (backend/node_modules) from a throwaway
/// random wallet — see docs/tickets/TICKET-MOBILE-001 step 3. Regenerate with:
///
/// ```js
/// const { TypedDataEncoder, Wallet, getAddress } = require('ethers');
/// const wallet = Wallet.createRandom();
/// // ...build domain/types/message as below, then:
/// TypedDataEncoder.hashDomain(domain);
/// TypedDataEncoder.from(types).hashStruct('TransferWithAuthorization', message);
/// TypedDataEncoder.hash(domain, types, message);
/// await wallet.signTypedData(domain, types, message);
/// ```
void main() {
  // Deliberately omits `EIP712Domain` from `types`, matching the backend's
  // contract note that `types` may omit it and it must be derived from
  // `domain`'s keys in canonical order.
  final typedData = Eip712TypedData(
    domain: const {
      'name': 'USDC',
      'version': '2',
      'chainId': 84532,
      'verifyingContract': '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    },
    types: const {
      'TransferWithAuthorization': [
        Eip712FieldType(name: 'from', type: 'address'),
        Eip712FieldType(name: 'to', type: 'address'),
        Eip712FieldType(name: 'value', type: 'uint256'),
        Eip712FieldType(name: 'validAfter', type: 'uint256'),
        Eip712FieldType(name: 'validBefore', type: 'uint256'),
        Eip712FieldType(name: 'nonce', type: 'bytes32'),
      ],
    },
    primaryType: 'TransferWithAuthorization',
    message: const {
      'from': '0xCa3337e0a5B11774eA57Ade79100B8F71A42d217',
      'to': '0x9E545E3C0baAB3E08CdfD552C960A1050f373042',
      'value': '2000000',
      'validAfter': '0',
      'validBefore': '1789000000',
      'nonce': '0x2f4f8f0e4b1d3a1c6e5f7a8b9c0d1e2f3a4b5c6d7e8f90112233445566778899',
    },
  );

  const expectedDomainSeparator = '0x71f17a3b2ff373b803d70a5a07c046c1a2bc8e89c09ef722fcb047abe94c9818';
  const expectedMessageHash = '0x1989372e2d5d736de1db14c161a89ef76743d4bfe1f9b5d82a9f54da55424575';
  const expectedDigest = '0xabe52193283a04a8a93d80e288ae7d94d4df2a88baa6cc78a7c88bf78900abb0';

  test('domain separator matches ethers TypedDataEncoder.hashDomain', () {
    final result = Eip712Hasher.hash(typedData);
    expect(result.domainSeparatorHex, expectedDomainSeparator);
  });

  test('message hash matches ethers TypedDataEncoder.hashStruct', () {
    final result = Eip712Hasher.hash(typedData);
    expect(result.messageHashHex, expectedMessageHash);
  });

  test('digest matches ethers TypedDataEncoder.hash (keccak256(0x1901 ‖ domainSeparator ‖ messageHash))', () {
    final result = Eip712Hasher.hash(typedData);
    expect(result.digestHex, expectedDigest);
  });

  test('encodeType puts the primary type first with no dependencies for this schema', () {
    expect(
      Eip712Hasher.encodeType('TransferWithAuthorization', typedData.types),
      'TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)',
    );
  });
}
