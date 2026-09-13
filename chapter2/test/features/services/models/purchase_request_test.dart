import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseJson({
  required String status,
  String? actionId,
  String? decision,
  List<String>? reasons,
  String? transactionHash,
  Map<String, dynamic>? response,
  String? error,
}) {
  return {
    'id': 'pr_1',
    'agentAddress': '0x1111111111111111111111111111111111111111',
    'serviceName': 'Open-Meteo Weather Oracle',
    'resourceUrl': 'https://chapter2-backend.onrender.com/x402/weather',
    'queryParams': {'city': 'Lagos'},
    'justification': 'Purchase weather data for company use',
    'amount': '10000',
    'status': status,
    'actionId': actionId,
    'decision': decision,
    'reasons': reasons ?? <String>[],
    'transactionHash': transactionHash,
    'response': response,
    'error': error,
    'createdAt': '2026-09-13T06:00:00.000Z',
    'updatedAt': '2026-09-13T06:00:05.000Z',
  };
}

void main() {
  group('PurchaseRequestStatus', () {
    test('round-trips every server status string', () {
      const statuses = [
        'QUEUED',
        'PROCESSING',
        'AUTHORIZED',
        'PAID',
        'BLOCKED',
        'REJECTED',
        'EXPIRED',
        'FAILED',
      ];
      for (final raw in statuses) {
        final status = PurchaseRequestStatus.fromServerString(raw);
        expect(status.toServerString(), raw, reason: 'round trip for $raw');
      }
    });

    test('terminal statuses stop polling; in-flight ones do not', () {
      const terminal = [
        PurchaseRequestStatus.paid,
        PurchaseRequestStatus.blocked,
        PurchaseRequestStatus.rejected,
        PurchaseRequestStatus.expired,
        PurchaseRequestStatus.failed,
      ];
      const inFlight = [
        PurchaseRequestStatus.queued,
        PurchaseRequestStatus.processing,
        PurchaseRequestStatus.authorized,
      ];
      for (final status in terminal) {
        expect(status.isTerminal, isTrue, reason: '$status should be terminal');
      }
      for (final status in inFlight) {
        expect(status.isTerminal, isFalse, reason: '$status should not be terminal');
      }
    });

    test('throws on an unrecognized status rather than silently coercing it', () {
      expect(() => PurchaseRequestStatus.fromServerString('SOMETHING_ELSE'), throwsFormatException);
    });
  });

  group('PurchaseRequest.fromJson', () {
    test('QUEUED has no decision, actionId or transaction yet', () {
      final request = PurchaseRequest.fromJson(_baseJson(status: 'QUEUED'));
      expect(request.status, PurchaseRequestStatus.queued);
      expect(request.decision, isNull);
      expect(request.actionId, isNull);
      expect(request.transactionHash, isNull);
      expect(request.response, isNull);
      expect(request.error, isNull);
      expect(request.queryParams, {'city': 'Lagos'});
      expect(request.amountAtomicUnits, '10000');
    });

    test('PROCESSING is claimed by the agent but not yet authorized', () {
      final request = PurchaseRequest.fromJson(_baseJson(status: 'PROCESSING'));
      expect(request.status, PurchaseRequestStatus.processing);
      expect(request.decision, isNull);
    });

    test('AUTHORIZED with ALLOW carries the decision and actionId', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(status: 'AUTHORIZED', actionId: 'act_1', decision: 'ALLOW'),
      );
      expect(request.status, PurchaseRequestStatus.authorized);
      expect(request.decision, GuardianVerdict.allow);
      expect(request.actionId, 'act_1');
    });

    test('AUTHORIZED with ESCALATE carries reasons for the Ledger approver', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(
          status: 'AUTHORIZED',
          actionId: 'act_2',
          decision: 'ESCALATE',
          reasons: ['Exceeds autonomous limit'],
        ),
      );
      expect(request.decision, GuardianVerdict.escalate);
      expect(request.reasons, ['Exceeds autonomous limit']);
    });

    test('PAID carries the transaction hash and the resource response', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(
          status: 'PAID',
          actionId: 'act_3',
          decision: 'ALLOW',
          transactionHash: '0xabc123',
          response: {'city': 'Lagos', 'temperatureC': 29.4},
        ),
      );
      expect(request.status, PurchaseRequestStatus.paid);
      expect(request.transactionHash, '0xabc123');
      expect(request.response, {'city': 'Lagos', 'temperatureC': 29.4});
    });

    test('BLOCKED carries the Guardian decision and reasons, no transaction', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(status: 'BLOCKED', decision: 'BLOCK', reasons: ['Payee is not approved']),
      );
      expect(request.status, PurchaseRequestStatus.blocked);
      expect(request.decision, GuardianVerdict.block);
      expect(request.reasons, ['Payee is not approved']);
      expect(request.transactionHash, isNull);
    });

    test('REJECTED carries the error text', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(status: 'REJECTED', error: 'Agent declined to pay'),
      );
      expect(request.status, PurchaseRequestStatus.rejected);
      expect(request.error, 'Agent declined to pay');
    });

    test('EXPIRED carries the error text', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(status: 'EXPIRED', error: 'Authorization expired before payment'),
      );
      expect(request.status, PurchaseRequestStatus.expired);
      expect(request.error, 'Authorization expired before payment');
    });

    test('FAILED carries the error text', () {
      final request = PurchaseRequest.fromJson(
        _baseJson(status: 'FAILED', error: 'Facilitator settlement failed'),
      );
      expect(request.status, PurchaseRequestStatus.failed);
      expect(request.error, 'Facilitator settlement failed');
    });
  });
}
