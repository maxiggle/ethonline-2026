import 'dart:convert';
import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/eip712/eip712_hash_result.dart';
import 'package:chapter2/features/x402_approvals/eip712/eip712_typed_data.dart';
import 'package:chapter2/features/x402_approvals/utils/byte_utils.dart';
import 'package:pointycastle/digests/keccak.dart';

/// Implements the EIP-712 `encodeType` / `encodeData` / `hashStruct` algorithm
/// for the field types this app needs: `string`, `uint256`, `address` and
/// `bytes32`, plus a generic struct walk so nested or future struct types
/// keep working without code changes.
///
/// Reference: https://eips.ethereum.org/EIPS/eip-712
class Eip712Hasher {
  const Eip712Hasher._();

  static const List<String> _domainFieldOrder = [
    'name',
    'version',
    'chainId',
    'verifyingContract',
    'salt',
  ];

  /// Hashes a full typed-data payload, deriving `EIP712Domain` from the keys
  /// present in `domain` (in the EIP-712 canonical order) when `types` omits it.
  static Eip712HashResult hash(Eip712TypedData typedData) {
    final types = _withDomainType(typedData.domain, typedData.types);
    final domainSeparator = hashStruct('EIP712Domain', types, typedData.domain);
    final messageHash = hashStruct(typedData.primaryType, types, typedData.message);
    return Eip712HashResult(
      domainSeparator: domainSeparator,
      messageHash: messageHash,
      digest: digest(domainSeparator, messageHash),
    );
  }

  /// `keccak256(0x1901 ‖ domainSeparator ‖ hashStruct(message))`, the digest
  /// an `eth_signTypedData_v4` signature is produced over.
  static Uint8List digest(Uint8List domainSeparator, Uint8List messageHash) {
    final buffer = BytesBuilder();
    buffer.add(const [0x19, 0x01]);
    buffer.add(domainSeparator);
    buffer.add(messageHash);
    return _keccak256(buffer.toBytes());
  }

  static Uint8List hashStruct(
    String primaryType,
    Map<String, List<Eip712FieldType>> types,
    Map<String, dynamic> data,
  ) {
    final buffer = BytesBuilder();
    buffer.add(typeHash(primaryType, types));
    buffer.add(encodeData(primaryType, types, data));
    return _keccak256(buffer.toBytes());
  }

  static Uint8List typeHash(String primaryType, Map<String, List<Eip712FieldType>> types) {
    return _keccak256(Uint8List.fromList(utf8.encode(encodeType(primaryType, types))));
  }

  /// `Name(type1 name1,type2 name2,...)`, followed by the same encoding of
  /// every struct type it (transitively) references, sorted alphabetically.
  static String encodeType(String primaryType, Map<String, List<Eip712FieldType>> types) {
    final dependencies = _findDependencies(primaryType, types)..remove(primaryType);
    final ordered = [primaryType, ...dependencies.toList()..sort()];

    final buffer = StringBuffer();
    for (final typeName in ordered) {
      final fields = types[typeName];
      if (fields == null) {
        throw ArgumentError('Unknown EIP-712 type referenced: $typeName');
      }
      buffer
        ..write(typeName)
        ..write('(')
        ..write(fields.map((field) => '${field.type} ${field.name}').join(','))
        ..write(')');
    }
    return buffer.toString();
  }

  static Uint8List encodeData(
    String primaryType,
    Map<String, List<Eip712FieldType>> types,
    Map<String, dynamic> data,
  ) {
    final fields = types[primaryType];
    if (fields == null) {
      throw ArgumentError('Unknown EIP-712 type: $primaryType');
    }
    final buffer = BytesBuilder();
    for (final field in fields) {
      if (!data.containsKey(field.name)) {
        throw ArgumentError('Missing EIP-712 field "${field.name}" for type $primaryType');
      }
      buffer.add(_encodeValue(field.type, data[field.name], types));
    }
    return buffer.toBytes();
  }

  static Uint8List _encodeValue(
    String type,
    dynamic value,
    Map<String, List<Eip712FieldType>> types,
  ) {
    if (type == 'string') {
      return _keccak256(Uint8List.fromList(utf8.encode(value as String)));
    }
    if (type == 'bytes') {
      return _keccak256(ByteUtils.hexToBytes(value as String));
    }
    if (type == 'bool') {
      final isTrue = value == true || value == 'true';
      return ByteUtils.leftPad(Uint8List.fromList([isTrue ? 1 : 0]), 32);
    }
    if (type == 'address') {
      final addressBytes = ByteUtils.hexToBytes(value as String);
      if (addressBytes.length != 20) {
        throw ArgumentError('Expected a 20-byte address, got ${addressBytes.length} bytes for "$value"');
      }
      return ByteUtils.leftPad(addressBytes, 32);
    }

    final uintMatch = RegExp(r'^uint(\d*)$').firstMatch(type);
    if (uintMatch != null) {
      return ByteUtils.leftPad(ByteUtils.bigIntToBytes(ByteUtils.toBigInt(value as Object)), 32);
    }

    final bytesNMatch = RegExp(r'^bytes(\d+)$').firstMatch(type);
    if (bytesNMatch != null) {
      final expectedLength = int.parse(bytesNMatch.group(1)!);
      final bytes = ByteUtils.hexToBytes(value as String);
      if (bytes.length != expectedLength) {
        throw ArgumentError('Expected $expectedLength bytes for $type, got ${bytes.length}');
      }
      return ByteUtils.rightPad(bytes, 32);
    }

    final arrayMatch = RegExp(r'^(.+)\[(\d*)\]$').firstMatch(type);
    if (arrayMatch != null) {
      final baseType = arrayMatch.group(1)!;
      final items = value as List;
      final buffer = BytesBuilder();
      for (final item in items) {
        buffer.add(_encodeValue(baseType, item, types));
      }
      return _keccak256(buffer.toBytes());
    }

    if (types.containsKey(type)) {
      return hashStruct(type, types, Map<String, dynamic>.from(value as Map));
    }

    throw ArgumentError('Unsupported EIP-712 field type: $type');
  }

  static Set<String> _findDependencies(
    String primaryType,
    Map<String, List<Eip712FieldType>> types, [
    Set<String>? found,
  ]) {
    final result = found ?? <String>{};
    if (result.contains(primaryType) || !types.containsKey(primaryType)) {
      return result;
    }
    result.add(primaryType);
    for (final field in types[primaryType]!) {
      final baseType = _stripArraySuffix(field.type);
      if (types.containsKey(baseType)) {
        _findDependencies(baseType, types, result);
      }
    }
    return result;
  }

  static String _stripArraySuffix(String type) {
    final index = type.indexOf('[');
    return index == -1 ? type : type.substring(0, index);
  }

  static Map<String, List<Eip712FieldType>> _withDomainType(
    Map<String, dynamic> domain,
    Map<String, List<Eip712FieldType>> types,
  ) {
    if (types.containsKey('EIP712Domain')) return types;

    final fields = _domainFieldOrder.where(domain.containsKey).map((name) {
      final type = switch (name) {
        'name' => 'string',
        'version' => 'string',
        'chainId' => 'uint256',
        'verifyingContract' => 'address',
        'salt' => 'bytes32',
        _ => throw StateError('Unreachable domain field: $name'),
      };
      return Eip712FieldType(name: name, type: type);
    }).toList();

    return {...types, 'EIP712Domain': fields};
  }

  static Uint8List _keccak256(Uint8List input) {
    return KeccakDigest(256).process(input);
  }
}
