import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/dashboard/models/treasury_metrics.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';

void main() {
  group('Chapter 2 Domain Lexicon & Models Test', () {
    test('GuardianVerdict values and labels match Chapter 2 trust perimeter', () {
      expect(GuardianVerdict.allow.label, 'ALLOW');
      expect(GuardianVerdict.escalate.label, 'ESCALATE');
      expect(GuardianVerdict.block.label, 'BLOCK');
      expect(GuardianVerdict.allow.isAllowed, isTrue);
      expect(GuardianVerdict.escalate.isEscalated, isTrue);
      expect(GuardianVerdict.block.isBlocked, isTrue);
    });

    test('TreasuryAction correctly identifies escalation threshold', () {
      final benignAction = TreasuryAction(
        actionId: 'act_40',
        agentAddress: '0x002',
        recipientAddress: '0x0041c4e',
        tokenAddress: '0x999',
        amountUnits: BigInt.from(40000000),
        amountDisplayUsdc: 40.0,
        status: TreasuryActionStatus.executed,
        riskScore: 12,
        purpose: 'RPC Billing',
        timestamp: DateTime.now(),
      );
      expect(benignAction.requiresEscalation, isFalse);

      final escalatedAction = TreasuryAction(
        actionId: 'act_850',
        agentAddress: '0x002',
        recipientAddress: '0x0041c4e',
        tokenAddress: '0x999',
        amountUnits: BigInt.from(850000000),
        amountDisplayUsdc: 850.0,
        status: TreasuryActionStatus.pending,
        riskScore: 78,
        purpose: 'Annual renewal',
        timestamp: DateTime.now(),
      );
      expect(escalatedAction.requiresEscalation, isTrue);
    });

    test('TreasuryMandate calculates remaining budget and checks recipients', () {
      final mandate = TreasuryMandate(
        maxAutonomousAmountUsdc: 100.0,
        dailyAutonomousLimitUsdc: 500.0,
        currentDailySpentUsdc: 200.0,
        approvedRecipients: const ['0x0000000000000000000000000000000000041c4e'],
        approvedTokens: const ['0x999'],
        safeAddress: '0xSafe',
        guardAddress: '0xGuard',
      );

      expect(mandate.remainingDailyBudgetUsdc, 300.0);
      expect(mandate.isRecipientApproved('0x0000000000000000000000000000000000041C4E'), isTrue);
      expect(mandate.isRecipientApproved('0xUnknownHacker'), isFalse);
    });

    test('TreasuryMetrics computes daily burn percentage accurately', () {
      const metrics = TreasuryMetrics(
        totalTreasuryBalanceUsdc: 100000.0,
        activeAutonomousAgentsCount: 3,
        todaySpentUsdc: 250.0,
        dailyAutonomousCapUsdc: 500.0,
        singleAutonomousCapUsdc: 100.0,
        pendingEscalationsCount: 1,
        blockedAttacksCount: 4,
      );

      expect(metrics.dailyBudgetBurnPercentage, 0.5);
    });

    test('Eip712ApprovalPayload serialization matches contract schema', () {
      final payload = Eip712ApprovalPayload(
        actionId: 'act_001',
        agentAddress: '0xAgent',
        recipientAddress: '0xRecipient',
        tokenAddress: '0xToken',
        amountUnits: BigInt.from(850000000),
        nonce: 101,
        deadline: 1800000000,
        mandateHash: '0xMandateHash',
        riskScore: 78,
      );

      final map = payload.toMap();
      expect(map['actionId'], 'act_001');
      expect(map['amount'], '850000000');
      expect(map['riskScore'], 78);
    });
  });
}
