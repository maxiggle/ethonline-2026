import 'package:equatable/equatable.dart';

class RejectActionRequest extends Equatable {
  const RejectActionRequest({required this.reason});

  final String reason;

  Map<String, dynamic> toJson() => {'reason': reason};

  factory RejectActionRequest.fromJson(Map<String, dynamic> json) {
    return RejectActionRequest(reason: (json['reason'] ?? '') as String);
  }

  @override
  List<Object?> get props => [reason];
}
