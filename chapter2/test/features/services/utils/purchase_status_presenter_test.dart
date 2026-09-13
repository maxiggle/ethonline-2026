import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/utils/purchase_status_presenter.dart';
import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseRequest _request({
  required PurchaseRequestStatus status,
  GuardianVerdict? decision,
  List<String> reasons = const [],
  String? error,
  DateTime? createdAt,
}) {
  final now = DateTime.now().toUtc();
  return PurchaseRequest(
    id: 'pr_1',
    agentAddress: '0x1111111111111111111111111111111111111111',
    serviceName: 'Open-Meteo Weather Oracle',
    resourceUrl: 'https://chapter2-backend.onrender.com/x402/weather',
    queryParams: const {'city': 'Lagos'},
    justification: 'Purchase weather data for company use',
    amountAtomicUnits: '10000',
    status: status,
    actionId: null,
    decision: decision,
    reasons: reasons,
    transactionHash: null,
    response: null,
    error: error,
    createdAt: createdAt ?? now,
    updatedAt: now,
  );
}

void main() {
  group('PurchaseStatusPresenter.describe', () {
    test('QUEUED shows the waiting message with no worker hint before 30s', () {
      final request = _request(status: PurchaseRequestStatus.queued, createdAt: DateTime.now().toUtc());
      final view = PurchaseStatusPresenter.describe(request, now: request.createdAt.add(const Duration(seconds: 5)));

      expect(view.headline, 'Waiting for your agent to pick this up.');
      expect(view.hint, isNull);
      expect(view.steps.first.state, PurchaseTimelineStepState.current);
    });

    test('QUEUED adds the worker hint once 30s have passed', () {
      final request = _request(status: PurchaseRequestStatus.queued, createdAt: DateTime.now().toUtc());
      final view = PurchaseStatusPresenter.describe(request, now: request.createdAt.add(const Duration(seconds: 31)));

      expect(view.hint, contains('npm --prefix scripts run agent:worker'));
    });

    test('PROCESSING shows the payment-terms message', () {
      final view = PurchaseStatusPresenter.describe(_request(status: PurchaseRequestStatus.processing));
      expect(view.headline, 'Agent is requesting payment terms…');
      expect(view.tone, PurchaseStatusTone.neutral);
    });

    test('AUTHORIZED + ALLOW shows the Guardian-allowed message', () {
      final view = PurchaseStatusPresenter.describe(
        _request(status: PurchaseRequestStatus.authorized, decision: GuardianVerdict.allow),
      );
      expect(view.headline, 'Guardian allowed it. The agent is paying…');
      expect(view.tone, PurchaseStatusTone.allow);
      expect(view.showApprovalsCta, isFalse);
    });

    test('AUTHORIZED + ESCALATE asks for a Ledger approval and links to Approvals', () {
      final view = PurchaseStatusPresenter.describe(
        _request(
          status: PurchaseRequestStatus.authorized,
          decision: GuardianVerdict.escalate,
          reasons: const ['Exceeds autonomous limit'],
        ),
      );
      expect(view.headline, 'Needs your Ledger approval');
      expect(view.reasons, ['Exceeds autonomous limit']);
      expect(view.showApprovalsCta, isTrue);
      expect(view.tone, PurchaseStatusTone.escalate);
    });

    test('PAID shows Paid with every step done', () {
      final view = PurchaseStatusPresenter.describe(_request(status: PurchaseRequestStatus.paid));
      expect(view.headline, 'Paid');
      expect(view.tone, PurchaseStatusTone.allow);
      expect(view.steps.every((step) => step.state == PurchaseTimelineStepState.done), isTrue);
    });

    test('BLOCKED shows the Guardian reasons in block tone', () {
      final view = PurchaseStatusPresenter.describe(
        _request(status: PurchaseRequestStatus.blocked, reasons: const ['Payee is not approved']),
      );
      expect(view.headline, 'Blocked by the Guardian');
      expect(view.reasons, ['Payee is not approved']);
      expect(view.tone, PurchaseStatusTone.block);
      expect(view.steps[2].state, PurchaseTimelineStepState.error);
    });

    test('REJECTED shows the error text', () {
      final view = PurchaseStatusPresenter.describe(
        _request(status: PurchaseRequestStatus.rejected, error: 'Agent declined to pay'),
      );
      expect(view.headline, 'Agent declined to pay');
      expect(view.tone, PurchaseStatusTone.block);
    });

    test('EXPIRED shows the error text', () {
      final view = PurchaseStatusPresenter.describe(
        _request(status: PurchaseRequestStatus.expired, error: 'Authorization expired'),
      );
      expect(view.headline, 'Authorization expired');
    });

    test('FAILED after a recorded decision marks the Paid step as the error', () {
      final view = PurchaseStatusPresenter.describe(
        _request(status: PurchaseRequestStatus.failed, decision: GuardianVerdict.allow, error: 'Settlement failed'),
      );
      expect(view.headline, 'Settlement failed');
      expect(view.steps[2].state, PurchaseTimelineStepState.done);
      expect(view.steps[3].state, PurchaseTimelineStepState.error);
    });

    test('FAILED with no recorded decision marks the Authorized step as the error', () {
      final view = PurchaseStatusPresenter.describe(
        _request(status: PurchaseRequestStatus.failed, error: 'Claim expired before authorization'),
      );
      expect(view.steps[2].state, PurchaseTimelineStepState.error);
      expect(view.steps[3].state, PurchaseTimelineStepState.pending);
    });

    test('a terminal failure with no error text still shows a headline naming the status', () {
      final view = PurchaseStatusPresenter.describe(_request(status: PurchaseRequestStatus.failed));
      expect(view.headline, contains('FAILED'));
    });
  });
}
