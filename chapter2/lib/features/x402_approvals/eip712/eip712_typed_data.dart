import 'package:equatable/equatable.dart';

/// One field of an EIP-712 struct definition, e.g. `{"name":"from","type":"address"}`.
class Eip712FieldType extends Equatable {
  const Eip712FieldType({required this.name, required this.type});

  final String name;
  final String type;

  factory Eip712FieldType.fromJson(Map<String, dynamic> json) {
    return Eip712FieldType(
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }

  @override
  List<Object?> get props => [name, type];
}

/// The `typedData` payload returned by `GET /x402/approvals/pending`, shaped
/// like an EIP-712 `eth_signTypedData_v4` request but without a guaranteed
/// `EIP712Domain` entry in `types` (the backend derives it from `domain`).
class Eip712TypedData extends Equatable {
  const Eip712TypedData({
    required this.domain,
    required this.types,
    required this.primaryType,
    required this.message,
  });

  final Map<String, dynamic> domain;
  final Map<String, List<Eip712FieldType>> types;
  final String primaryType;
  final Map<String, dynamic> message;

  factory Eip712TypedData.fromJson(Map<String, dynamic> json) {
    final rawTypes = Map<String, dynamic>.from(json['types'] as Map? ?? const {});
    final types = <String, List<Eip712FieldType>>{};
    for (final entry in rawTypes.entries) {
      final fields = entry.value as List;
      types[entry.key] = fields
          .map((field) => Eip712FieldType.fromJson(Map<String, dynamic>.from(field as Map)))
          .toList();
    }
    return Eip712TypedData(
      domain: Map<String, dynamic>.from(json['domain'] as Map),
      types: types,
      primaryType: json['primaryType'] as String,
      message: Map<String, dynamic>.from(json['message'] as Map),
    );
  }

  @override
  List<Object?> get props => [domain, types, primaryType, message];
}
