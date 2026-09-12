import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/guardian_alert/models/guardian_decision.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/api/models/models.dart';
import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

class MockE2EChapter2ApiService extends Chapter2ApiService {
  final List<TreasuryAction> _inMemoryActions = [];

  @override
  Future<ProposeActionResponse> proposeAction(ProposeActionRequest request) async {
    final amountUsdc = double.tryParse(request.amount) ?? 0.0;
    final recipient = request.recipient.toLowerCase();
    final approvedRecipient = '0x0000000000000000000000000000000000041c4e'.toLowerCase();
    final actionId = 'act_${DateTime.now().millisecondsSinceEpoch}';

    if (recipient != approvedRecipient) {
      final action = TreasuryAction(
        actionId: actionId,
        agentAddress: request.agentAddress,
        recipientAddress: request.recipient,
        tokenAddress: request.token,
        amountUnits: BigInt.from((amountUsdc * 1e6).toInt()),
        amountDisplayUsdc: amountUsdc,
        status: TreasuryActionStatus.rejected,
        riskScore: 100,
        purpose: request.justification,
        timestamp: DateTime.now(),
      );
      final decision = GuardianDecision(
        actionId: actionId,
        verdict: GuardianVerdict.block,
        riskScore: 100,
        deterministicPass: false,
        reason: 'RecipientNotApproved',
        adversarialFactors: const ['RecipientNotApproved', 'Untrusted Destination Address'],
        timestamp: DateTime.now(),
      );
      _inMemoryActions.add(action);
      return ProposeActionResponse(action: action, decision: decision);
    }

    if (amountUsdc <= 100.0) {
      final action = TreasuryAction(
        actionId: actionId,
        agentAddress: request.agentAddress,
        recipientAddress: request.recipient,
        tokenAddress: request.token,
        amountUnits: BigInt.from((amountUsdc * 1e6).toInt()),
        amountDisplayUsdc: amountUsdc,
        status: TreasuryActionStatus.executed,
        riskScore: 15,
        purpose: request.justification,
        timestamp: DateTime.now(),
        txHash: '0x3819238910283019283019238102938102938102938102938102938102938102',
      );
      final decision = GuardianDecision(
        actionId: actionId,
        verdict: GuardianVerdict.allow,
        riskScore: 15,
        deterministicPass: true,
        reason: 'Within autonomous limits',
        adversarialFactors: const [],
        timestamp: DateTime.now(),
      );
      _inMemoryActions.add(action);
      return ProposeActionResponse(action: action, decision: decision);
    } else {
      final action = TreasuryAction(
        actionId: actionId,
        agentAddress: request.agentAddress,
        recipientAddress: request.recipient,
        tokenAddress: request.token,
        amountUnits: BigInt.from((amountUsdc * 1e6).toInt()),
        amountDisplayUsdc: amountUsdc,
        status: TreasuryActionStatus.pending,
        riskScore: 78,
        purpose: request.justification,
        timestamp: DateTime.now(),
        nonce: 101,
      );
      final decision = GuardianDecision(
        actionId: actionId,
        verdict: GuardianVerdict.escalate,
        riskScore: 78,
        deterministicPass: true,
        reason: 'Exceeds autonomous spending cap ($amountUsdc > 100)',
        adversarialFactors: ['Exceeds autonomous spending cap ($amountUsdc > 100)'],
        timestamp: DateTime.now(),
      );
      final typedData = Eip712ApprovalPayload(
        actionId: actionId,
        agentAddress: request.agentAddress,
        recipientAddress: request.recipient,
        tokenAddress: request.token,
        amountUnits: BigInt.from((amountUsdc * 1e6).toInt()),
        nonce: 101,
        deadline: 1800000000,
        mandateHash: '0xMandateHash',
        riskScore: 78,
      );
      _inMemoryActions.add(action);
      return ProposeActionResponse(
        action: action,
        decision: decision,
        typedData: typedData,
      );
    }
  }

  @override
  Future<List<TreasuryAction>> fetchActions({TreasuryActionStatus? status}) async {
    if (status != null) {
      return _inMemoryActions.where((a) => a.status == status).toList();
    }
    return _inMemoryActions;
  }

  @override
  Future<TreasuryAction?> fetchActionById(String actionId) async {
    return _inMemoryActions.cast<TreasuryAction?>().firstWhere(
          (a) => a?.actionId == actionId,
          orElse: () => null,
        );
  }

  @override
  Future<ApproveActionResponse> approveAction(
    String actionId,
    SubmitApprovalRequest request,
  ) async {
    final existingIndex = _inMemoryActions.indexWhere((a) => a.actionId == actionId);
    final executedAction = TreasuryAction(
      actionId: actionId,
      agentAddress: '0xAgent002',
      recipientAddress: '0x0000000000000000000000000000000000041c4e',
      tokenAddress: '0x999',
      amountUnits: BigInt.from(850 * 1e6),
      amountDisplayUsdc: 850.0,
      status: TreasuryActionStatus.executed,
      riskScore: 78,
      purpose: 'Alchemy Enterprise Dedicated cluster renewal',
      timestamp: DateTime.now(),
      txHash: '0x7e8b61c9e83b482fa89b21f98d02341acb983741829037412839471928374123',
    );

    if (existingIndex >= 0) {
      _inMemoryActions[existingIndex] = executedAction;
    } else {
      _inMemoryActions.add(executedAction);
    }

    return ApproveActionResponse(
      action: executedAction,
      encodedPayload: '0xEscalatedExecutionPayloadBytes',
      signer: request.signer,
      txHash: executedAction.txHash,
    );
  }
}

void main() {
  group('Chapter 2 End-to-End Tri-Verdict Scenario Validation', () {
    late MockE2EChapter2ApiService apiService;
    late DashboardCubit dashboardCubit;
    late ApprovalCubit approvalCubit;
    late TreasuryMandate mandate;

    setUp(() {
      apiService = MockE2EChapter2ApiService();
      dashboardCubit = DashboardCubit(apiService: apiService);
      approvalCubit = ApprovalCubit(apiService: apiService);
      mandate = const TreasuryMandate(
        maxAutonomousAmountUsdc: 100.0,
        dailyAutonomousLimitUsdc: 500.0,
        currentDailySpentUsdc: 0.0,
        approvedRecipients: ['0x0000000000000000000000000000000000041c4e'],
        approvedTokens: ['0x999'],
        safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
      );
    });

    test('Scenario 1: \$40 RPC bill is evaluated as ALLOW automatically', () async {
      const request = ProposeActionRequest(
        target: '0x999',
        value: '0',
        data: '0xa9059cbb',
        token: '0x999',
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '40',
        agentAddress: '0xAgent002',
        justification: 'Alchemy monthly RPC node infrastructure',
      );

      final response = await apiService.proposeAction(request);
      expect(response.decision.verdict, GuardianVerdict.allow);
      expect(response.action.status, TreasuryActionStatus.executed);
      expect(response.action.requiresEscalation, isFalse);
      expect(response.action.amountDisplayUsdc, 40.0);
      expect(mandate.isRecipientApproved(response.action.recipientAddress), isTrue);
      expect(response.typedData, isNull);
    });

    test('Scenario 2: \$850 Renewal is ESCALATED, passes biometric challenge, signs with Ledger, and executes on-chain', () async {
      const request = ProposeActionRequest(
        target: '0x999',
        value: '0',
        data: '0xa9059cbb',
        token: '0x999',
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '850',
        agentAddress: '0xAgent002',
        justification: 'Alchemy Enterprise Dedicated cluster renewal',
      );

      final response = await apiService.proposeAction(request);
      expect(response.decision.verdict, GuardianVerdict.escalate);
      expect(response.action.status, TreasuryActionStatus.pending);
      expect(response.action.requiresEscalation, isTrue);
      expect(response.typedData, isNotNull);

      final eip712Payload = response.typedData!;
      expect(eip712Payload.amountUnits, BigInt.from(850000000));
      expect(eip712Payload.riskScore, 78);

      approvalCubit.initializeApproval(eip712Payload);
      expect(approvalCubit.state.status, ApprovalStepStatus.ledgerClearSignReview);
      expect(approvalCubit.state.payload, eip712Payload);

      await approvalCubit.confirmBiometricChallenge();
      expect(approvalCubit.state.status, ApprovalStepStatus.biometricsVerified);

      const mockHardwareSignature = '0x32849234892374829374928374982374982374982374928374';
      await approvalCubit.submitHardwareApproval(
        humanSignatureHex: mockHardwareSignature,
        signerAddress: '0x0000000000000000000000000000000000041c4e',
      );

      expect(approvalCubit.state.status, ApprovalStepStatus.approvedSuccess);
      expect(approvalCubit.state.txHash, startsWith('0x7e8b61c9'));

      final updatedAction = await apiService.fetchActionById(response.action.actionId);
      expect(updatedAction, isNotNull);
      expect(updatedAction!.status, TreasuryActionStatus.executed);
    });

    test('Scenario 3: \$5,000 Unknown transfer to unapproved address is BLOCKED immediately', () async {
      const maliciousRequest = ProposeActionRequest(
        target: '0x999',
        value: '0',
        data: '0xa9059cbb',
        token: '0x999',
        recipient: '0x8F0000000000000000000000000000000000072A',
        amount: '5000',
        agentAddress: '0xAgent002',
        justification: 'Urgent treasury rebalancing to external offshore liquidity pool',
      );

      final response = await apiService.proposeAction(maliciousRequest);
      expect(response.decision.verdict, GuardianVerdict.block);
      expect(response.action.status, TreasuryActionStatus.rejected);
      expect(response.decision.reason, 'RecipientNotApproved');
      expect(response.decision.adversarialFactors, contains('RecipientNotApproved'));
      expect(mandate.isRecipientApproved(maliciousRequest.recipient), isFalse);

      await dashboardCubit.loadDashboardMetrics();
      expect(dashboardCubit.state.metrics?.blockedAttacksCount, 1);
    });

    test('Scenario 4: Serialization round-trips for requests and responses', () {
      const request = ProposeActionRequest(
        target: '0x999',
        value: '0',
        data: '0xa9059cbb',
        token: '0x999',
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '100',
        agentAddress: '0xAgent',
        justification: 'Test justification',
      );

      final json = request.toJson();
      final roundTrip = ProposeActionRequest.fromJson(json);
      expect(roundTrip, equals(request));
    });
  });
}
