import 'package:chapter2/features/world_id/cubit/world_id_approver_cubit.dart';
import 'package:chapter2/features/world_id/cubit/world_id_approver_state.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_approver_status.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';
import 'package:chapter2/features/world_id/remote/world_id_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldIdApiService extends WorldIdApiService {
  _FakeWorldIdApiService() : super(apiClient: null);

  WorldIdApproverStatus? approverStatus;
  WorldIdOrbVerification? startVerificationResult;
  List<WorldIdOrbVerification> pollResults = [];
  int pollIndex = 0;

  String? boundRequestId;
  String? boundSignature;
  WorldIdApproverStatus? bindResult;

  @override
  Future<WorldIdApproverStatus> fetchApproverStatus() async {
    if (approverStatus != null) return approverStatus!;
    throw Exception('No approver status configured');
  }

  @override
  Future<WorldIdOrbVerification> startOrbVerification() async {
    if (startVerificationResult != null) return startVerificationResult!;
    throw Exception('No start verification configured');
  }

  @override
  Future<WorldIdOrbVerification> fetchOrbVerification(String requestId) async {
    if (pollIndex < pollResults.length) {
      final res = pollResults[pollIndex];
      pollIndex++;
      return res;
    }
    throw Exception('No more poll results configured');
  }

  @override
  Future<WorldIdApproverStatus> bindLedgerApprover({
    required String requestId,
    required String signature,
  }) async {
    boundRequestId = requestId;
    boundSignature = signature;
    if (bindResult != null) return bindResult!;
    throw Exception('No bind result configured');
  }
}

void main() {
  group('WorldIdApproverCubit', () {
    late _FakeWorldIdApiService apiService;

    setUp(() {
      apiService = _FakeWorldIdApiService();
    });

    test('loadStatus() fetches approver status and updates state', () async {
      apiService.approverStatus = const WorldIdApproverStatus(
        approverAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        isWorldIdRequired: true,
        isWorldIdConfigured: true,
        environment: 'staging',
        isVerified: false,
      );

      final cubit = WorldIdApproverCubit(apiService: apiService);
      await cubit.loadStatus();

      expect(cubit.state.status, WorldIdApproverCubitStatus.ready);
      expect(cubit.state.isWorldIdRequired, isTrue);
      expect(cubit.state.isVerified, isFalse);

      await cubit.close();
    });

    test('startOrbVerification -> WAITING_FOR_WORLD_APP -> VERIFIED stops polling', () async {
      apiService.startVerificationResult = WorldIdOrbVerification(
        requestId: 'req-1',
        status: WorldIdOrbVerificationStatus.waitingForWorldApp,
        connectorUrl: 'https://worldcoin.org/verify?t=test',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      apiService.pollResults = [
        WorldIdOrbVerification(
          requestId: 'req-1',
          status: WorldIdOrbVerificationStatus.awaitingConfirmation,
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
        WorldIdOrbVerification(
          requestId: 'req-1',
          status: WorldIdOrbVerificationStatus.verified,
          bindMessage: 'chapter2-world-bind:0xnullifier',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      ];

      final cubit = WorldIdApproverCubit(
        apiService: apiService,
        pollInterval: const Duration(milliseconds: 15),
      );

      await cubit.startOrbVerification();
      expect(cubit.state.verification?.status, WorldIdOrbVerificationStatus.waitingForWorldApp);

      // Wait for poll 1 and poll 2 to complete
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.verification?.status, WorldIdOrbVerificationStatus.verified);
      expect(cubit.state.verification?.bindMessage, 'chapter2-world-bind:0xnullifier');

      final pollsBefore = apiService.pollIndex;

      // Wait more: polling should have stopped
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(apiService.pollIndex, pollsBefore);

      await cubit.close();
    });

    test('FAILED status surfaces errorMessage and stops polling', () async {
      apiService.startVerificationResult = WorldIdOrbVerification(
        requestId: 'req-fail',
        status: WorldIdOrbVerificationStatus.waitingForWorldApp,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      apiService.pollResults = [
        WorldIdOrbVerification(
          requestId: 'req-fail',
          status: WorldIdOrbVerificationStatus.failed,
          errorMessage: 'Nullifier bound to another signer',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      ];

      final cubit = WorldIdApproverCubit(
        apiService: apiService,
        pollInterval: const Duration(milliseconds: 15),
      );

      await cubit.startOrbVerification();

      // Wait for poll to complete
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cubit.state.verification?.status, WorldIdOrbVerificationStatus.failed);
      expect(cubit.state.errorMessage, 'Nullifier bound to another signer');

      final pollsBefore = apiService.pollIndex;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(apiService.pollIndex, pollsBefore);

      await cubit.close();
    });

    test('bindWithLedger passes bindMessage to signer function, posts signature, and ends isVerified: true', () async {
      final verification = WorldIdOrbVerification(
        requestId: 'req-bind',
        status: WorldIdOrbVerificationStatus.verified,
        bindMessage: 'chapter2-world-bind:0xabc123',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      apiService.bindResult = const WorldIdApproverStatus(
        approverAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        isWorldIdRequired: true,
        isWorldIdConfigured: true,
        isVerified: true,
        credential: 'orb',
      );

      final cubit = WorldIdApproverCubit(apiService: apiService);
      // Seed state with VERIFIED verification
      cubit.emit(cubit.state.copyWith(verification: verification));

      String? messagePassedToLedger;
      Future<String> mockLedgerSigner(String message) async {
        messagePassedToLedger = message;
        return '0xbound_signature';
      }

      await cubit.bindWithLedger(mockLedgerSigner);

      expect(messagePassedToLedger, 'chapter2-world-bind:0xabc123');
      expect(apiService.boundRequestId, 'req-bind');
      expect(apiService.boundSignature, '0xbound_signature');
      expect(cubit.state.isVerified, isTrue);
      expect(cubit.state.verification, isNull);

      await cubit.close();
    });

    test('bindWithLedger before VERIFIED makes no network call', () async {
      final verification = WorldIdOrbVerification(
        requestId: 'req-unverified',
        status: WorldIdOrbVerificationStatus.waitingForWorldApp,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      final cubit = WorldIdApproverCubit(apiService: apiService);
      cubit.emit(cubit.state.copyWith(verification: verification));

      bool signerCalled = false;
      Future<String> mockLedgerSigner(String message) async {
        signerCalled = true;
        return '0xsignature';
      }

      await cubit.bindWithLedger(mockLedgerSigner);

      expect(signerCalled, isFalse);
      expect(apiService.boundRequestId, isNull);

      await cubit.close();
    });
  });
}
