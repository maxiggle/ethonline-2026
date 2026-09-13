import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:equatable/equatable.dart';

/// Lifecycle of an agent purchase request, exactly as defined by
/// X402-004's API contract.
enum PurchaseRequestStatus {
  queued,
  processing,
  authorized,
  paid,
  blocked,
  rejected,
  expired,
  failed;

  /// The exact wire value the backend uses for this status.
  String get label => toServerString();

  /// Whether the agent worker and Guardian are done deciding this request:
  /// no further polling can change it.
  bool get isTerminal => switch (this) {
        PurchaseRequestStatus.paid ||
        PurchaseRequestStatus.blocked ||
        PurchaseRequestStatus.rejected ||
        PurchaseRequestStatus.expired ||
        PurchaseRequestStatus.failed =>
          true,
        PurchaseRequestStatus.queued || PurchaseRequestStatus.processing || PurchaseRequestStatus.authorized => false,
      };

  String toServerString() {
    switch (this) {
      case PurchaseRequestStatus.queued:
        return 'QUEUED';
      case PurchaseRequestStatus.processing:
        return 'PROCESSING';
      case PurchaseRequestStatus.authorized:
        return 'AUTHORIZED';
      case PurchaseRequestStatus.paid:
        return 'PAID';
      case PurchaseRequestStatus.blocked:
        return 'BLOCKED';
      case PurchaseRequestStatus.rejected:
        return 'REJECTED';
      case PurchaseRequestStatus.expired:
        return 'EXPIRED';
      case PurchaseRequestStatus.failed:
        return 'FAILED';
    }
  }

  static PurchaseRequestStatus fromServerString(String value) {
    switch (value) {
      case 'QUEUED':
        return PurchaseRequestStatus.queued;
      case 'PROCESSING':
        return PurchaseRequestStatus.processing;
      case 'AUTHORIZED':
        return PurchaseRequestStatus.authorized;
      case 'PAID':
        return PurchaseRequestStatus.paid;
      case 'BLOCKED':
        return PurchaseRequestStatus.blocked;
      case 'REJECTED':
        return PurchaseRequestStatus.rejected;
      case 'EXPIRED':
        return PurchaseRequestStatus.expired;
      case 'FAILED':
        return PurchaseRequestStatus.failed;
      default:
        throw FormatException('Unknown purchase request status: $value');
    }
  }
}

GuardianVerdict? _parseGuardianDecision(dynamic raw) {
  if (raw == null) return null;
  switch (raw.toString()) {
    case 'ALLOW':
      return GuardianVerdict.allow;
    case 'ESCALATE':
      return GuardianVerdict.escalate;
    case 'BLOCK':
      return GuardianVerdict.block;
    default:
      throw FormatException('Unknown Guardian decision: $raw');
  }
}

/// One `PurchaseRequest` as returned by `/x402/purchase-requests*`
/// (X402-004's API contract).
class PurchaseRequest extends Equatable {
  const PurchaseRequest({
    required this.id,
    required this.agentAddress,
    required this.serviceName,
    required this.resourceUrl,
    required this.queryParams,
    required this.justification,
    required this.amountAtomicUnits,
    required this.status,
    required this.actionId,
    required this.decision,
    required this.reasons,
    required this.transactionHash,
    required this.response,
    required this.error,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String agentAddress;
  final String serviceName;
  final String resourceUrl;
  final Map<String, String> queryParams;
  final String justification;
  final String amountAtomicUnits;
  final PurchaseRequestStatus status;
  final String? actionId;
  final GuardianVerdict? decision;
  final List<String> reasons;
  final String? transactionHash;
  final Map<String, dynamic>? response;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    final rawQueryParams = Map<String, dynamic>.from(json['queryParams'] as Map? ?? const {});
    final rawResponse = json['response'];

    return PurchaseRequest(
      id: json['id'] as String,
      agentAddress: json['agentAddress'] as String,
      serviceName: json['serviceName'] as String,
      resourceUrl: json['resourceUrl'] as String,
      queryParams: rawQueryParams.map((key, value) => MapEntry(key, value.toString())),
      justification: json['justification'] as String,
      amountAtomicUnits: json['amount'].toString(),
      status: PurchaseRequestStatus.fromServerString(json['status'] as String),
      actionId: json['actionId'] as String?,
      decision: _parseGuardianDecision(json['decision']),
      reasons: List<String>.from(json['reasons'] as List? ?? const []),
      transactionHash: json['transactionHash'] as String?,
      response: rawResponse is Map ? Map<String, dynamic>.from(rawResponse) : null,
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        agentAddress,
        serviceName,
        resourceUrl,
        queryParams,
        justification,
        amountAtomicUnits,
        status,
        actionId,
        decision,
        reasons,
        transactionHash,
        response,
        error,
        createdAt,
        updatedAt,
      ];
}
