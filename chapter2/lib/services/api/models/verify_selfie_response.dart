import 'package:equatable/equatable.dart';

class VerifySelfieResponse extends Equatable {
  const VerifySelfieResponse({
    required this.success,
    this.error,
    this.nullifierHash,
  });

  final bool success;
  final String? error;
  final String? nullifierHash;

  factory VerifySelfieResponse.fromJson(Map<String, dynamic> json) {
    return VerifySelfieResponse(
      success: json['success'] == true,
      error: json['error'] as String?,
      nullifierHash: json['nullifierHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (error != null) 'error': error,
        if (nullifierHash != null) 'nullifierHash': nullifierHash,
      };

  @override
  List<Object?> get props => [success, error, nullifierHash];
}
