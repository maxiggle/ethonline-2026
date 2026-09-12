import 'package:chapter2/features/timeline/models/treasury_action.dart';

class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.provider,
    required this.name,
    required this.organization,
    required this.accountId,
    required this.status,
    required this.connectedAt,
    this.projects = const [],
  });

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) {
    return ConnectedAccount(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      name: json['name'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      accountId: json['accountId'] as String? ?? '',
      status: json['status'] as String? ?? 'CONNECTED',
      connectedAt: json['connectedAt'] as String? ?? '',
      projects: (json['projects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final String id;
  final String provider;
  final String name;
  final String organization;
  final String accountId;
  final String status;
  final String connectedAt;
  final List<String> projects;

  bool get isConnected => status.toUpperCase() == 'CONNECTED';

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'name': name,
        'organization': organization,
        'accountId': accountId,
        'status': status,
        'connectedAt': connectedAt,
        'projects': projects,
      };
}

class CompanyBill {
  const CompanyBill({
    required this.id,
    required this.provider,
    required this.serviceName,
    required this.accountId,
    required this.organization,
    required this.invoiceNumber,
    required this.amount,
    required this.amountUsdc,
    required this.description,
    required this.paymentIdentifier,
    required this.status,
    required this.dueDate,
    this.txHash,
  });

  factory CompanyBill.fromJson(Map<String, dynamic> json) {
    return CompanyBill(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      accountId: json['accountId'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
      amountUsdc: (json['amountUsdc'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      paymentIdentifier: json['paymentIdentifier'] as String? ?? '',
      status: json['status'] as String? ?? 'UNPAID_402',
      dueDate: json['dueDate'] as String? ?? '',
      txHash: json['txHash'] as String?,
    );
  }

  final String id;
  final String provider;
  final String serviceName;
  final String accountId;
  final String organization;
  final String invoiceNumber;
  final String amount;
  final double amountUsdc;
  final String description;
  final String paymentIdentifier;
  final String status;
  final String dueDate;
  final String? txHash;

  bool get isSettled => status.toUpperCase() == 'SETTLED_200';

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'serviceName': serviceName,
        'accountId': accountId,
        'organization': organization,
        'invoiceNumber': invoiceNumber,
        'amount': amount,
        'amountUsdc': amountUsdc,
        'description': description,
        'paymentIdentifier': paymentIdentifier,
        'status': status,
        'dueDate': dueDate,
        if (txHash != null) 'txHash': txHash,
      };
}

class PayBillResponse {
  const PayBillResponse({
    required this.bill,
    required this.action,
    required this.decision,
    this.typedData,
  });

  factory PayBillResponse.fromJson(Map<String, dynamic> json) {
    return PayBillResponse(
      bill: CompanyBill.fromJson(json['bill'] as Map<String, dynamic>? ?? {}),
      action: TreasuryAction.fromJson(json['action'] as Map<String, dynamic>? ?? {}),
      decision: json['decision'] as Map<String, dynamic>? ?? {},
      typedData: json['typedData'] as Map<String, dynamic>?,
    );
  }

  final CompanyBill bill;
  final TreasuryAction action;
  final Map<String, dynamic> decision;
  final Map<String, dynamic>? typedData;

  bool get requiresHumanApproval =>
      decision['requiresHumanApproval'] == true ||
      decision['decision'] == 'ESCALATE';
}

class BazaarResource {
  const BazaarResource({
    required this.resource,
    required this.type,
    required this.serviceName,
    required this.description,
    required this.priceUsdc,
    required this.payTo,
    required this.paymentIdentifier,
    this.tags = const [],
    this.method = 'GET',
    this.queryParams = const {},
    this.outputExample = const {},
  });

  factory BazaarResource.fromJson(Map<String, dynamic> json) {
    final extensions = json['extensions'] as Map<String, dynamic>? ?? {};
    final bazaar = extensions['bazaar'] as Map<String, dynamic>? ?? {};
    final info = bazaar['info'] as Map<String, dynamic>? ?? {};
    final accepts = (json['accepts'] as List<dynamic>?) ?? [];
    final firstAccept = accepts.isNotEmpty ? accepts.first as Map<String, dynamic> : {};
    final rawAmount = firstAccept['amount']?.toString() ?? '0';
    final amountParsed = double.tryParse(rawAmount) ?? 0.0;
    final extra = firstAccept['extra'] as Map<String, dynamic>? ?? {};
    final input = info['input'] as Map<String, dynamic>? ?? {};
    final output = info['output'] as Map<String, dynamic>? ?? {};

    return BazaarResource(
      resource: json['resource'] as String? ?? '',
      type: json['type'] as String? ?? 'http',
      serviceName: info['serviceName'] as String? ?? 'x402 Service',
      description: info['description'] as String? ?? '',
      priceUsdc: amountParsed >= 100000 ? amountParsed / 1000000.0 : amountParsed,
      payTo: firstAccept['payTo'] as String? ?? '',
      paymentIdentifier: extra['paymentIdentifier'] as String? ?? '',
      tags: (info['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      method: input['method'] as String? ?? 'GET',
      queryParams: input['queryParams'] as Map<String, dynamic>? ?? const {},
      outputExample: output['example'] as Map<String, dynamic>? ?? const {},
    );
  }

  final String resource;
  final String type;
  final String serviceName;
  final String description;
  final double priceUsdc;
  final String payTo;
  final String paymentIdentifier;
  final List<String> tags;
  final String method;
  final Map<String, dynamic> queryParams;
  final Map<String, dynamic> outputExample;
}

class BazaarInvocationResult {
  const BazaarInvocationResult({
    required this.status,
    required this.serviceName,
    required this.resourceUrl,
    required this.costUsdc,
    required this.decision,
    required this.executionTimestamp,
    this.txHash,
    this.data,
    this.reason,
    this.action,
  });

  factory BazaarInvocationResult.fromJson(Map<String, dynamic> json) {
    return BazaarInvocationResult(
      status: json['status'] as String? ?? 'SUCCESS',
      serviceName: json['serviceName'] as String? ?? '',
      resourceUrl: json['resourceUrl'] as String? ?? '',
      costUsdc: (json['costUsdc'] as num?)?.toDouble() ?? 0.0,
      decision: json['decision'] as String? ?? 'ALLOW',
      executionTimestamp: json['executionTimestamp'] as String? ?? '',
      txHash: json['txHash'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      reason: json['reason'] as String?,
      action: json['action'] != null
          ? TreasuryAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }

  final String status;
  final String serviceName;
  final String resourceUrl;
  final double costUsdc;
  final String decision;
  final String executionTimestamp;
  final String? txHash;
  final Map<String, dynamic>? data;
  final String? reason;
  final TreasuryAction? action;

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';
  bool get isEscalated => status.toUpperCase() == 'ESCALATED';
}
