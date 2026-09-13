import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';
import 'package:chapter2/features/world_id/remote/world_id_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final List<String> recordedCalls = [];
  final Map<String, dynamic> recordedData = {};

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    recordedCalls.add('GET $path');
    if (!responses.containsKey('GET $path')) {
      throw Exception('Unconfigured GET route: $path');
    }
    return responses['GET $path'];
  }

  @override
  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    recordedCalls.add('POST $path');
    recordedData['POST $path'] = data;
    if (!responses.containsKey('POST $path')) {
      throw Exception('Unconfigured POST route: $path');
    }
    return responses['POST $path'];
  }
}

void main() {
  late _FakeApiClient apiClient;
  late WorldIdApiService apiService;

  setUp(() {
    apiClient = _FakeApiClient();
    apiService = WorldIdApiService(apiClient: apiClient);
  });

  test('fetchApproverStatus calls GET /world/approver/status and parses response', () async {
    apiClient.responses['GET /world/approver/status'] = {
      'approverAddress': '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      'isWorldIdRequired': true,
      'isWorldIdConfigured': true,
      'environment': 'staging',
      'isVerified': false,
      'credential': null,
      'boundAt': null,
      'expiresAt': null,
    };

    final status = await apiService.fetchApproverStatus();
    expect(apiClient.recordedCalls, ['GET /world/approver/status']);
    expect(status.approverAddress, '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6');
    expect(status.isWorldIdRequired, isTrue);
    expect(status.isVerified, isFalse);
  });

  test('startOrbVerification calls POST /world/approver/orb-verifications and parses response', () async {
    apiClient.responses['POST /world/approver/orb-verifications'] = {
      'requestId': 'req-999',
      'status': 'WAITING_FOR_WORLD_APP',
      'connectorUrl': 'https://worldcoin.org/verify?t=test',
      'expiresAt': '2026-09-13T10:15:00.000Z',
      'bindMessage': null,
      'errorMessage': null,
    };

    final verification = await apiService.startOrbVerification();
    expect(apiClient.recordedCalls, ['POST /world/approver/orb-verifications']);
    expect(verification.requestId, 'req-999');
    expect(verification.status, WorldIdOrbVerificationStatus.waitingForWorldApp);
    expect(verification.connectorUrl, 'https://worldcoin.org/verify?t=test');
  });

  test('fetchOrbVerification calls GET /world/approver/orb-verifications/:id', () async {
    apiClient.responses['GET /world/approver/orb-verifications/req-999'] = {
      'requestId': 'req-999',
      'status': 'VERIFIED',
      'connectorUrl': null,
      'expiresAt': '2026-09-13T10:15:00.000Z',
      'bindMessage': 'chapter2-world-bind:0xnullifier',
      'errorMessage': null,
    };

    final verification = await apiService.fetchOrbVerification('req-999');
    expect(apiClient.recordedCalls, ['GET /world/approver/orb-verifications/req-999']);
    expect(verification.status, WorldIdOrbVerificationStatus.verified);
    expect(verification.bindMessage, 'chapter2-world-bind:0xnullifier');
  });

  test('bindLedgerApprover calls POST /world/approver/orb-verifications/:id/bind with signature', () async {
    apiClient.responses['POST /world/approver/orb-verifications/req-999/bind'] = {
      'approverAddress': '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      'isWorldIdRequired': true,
      'isWorldIdConfigured': true,
      'environment': 'staging',
      'isVerified': true,
      'credential': 'orb',
      'boundAt': '2026-09-13T10:00:00.000Z',
      'expiresAt': '2026-12-12T10:00:00.000Z',
    };

    final status = await apiService.bindLedgerApprover(
      requestId: 'req-999',
      signature: '0xsignature',
    );

    expect(apiClient.recordedCalls, ['POST /world/approver/orb-verifications/req-999/bind']);
    expect(apiClient.recordedData['POST /world/approver/orb-verifications/req-999/bind'], {
      'signature': '0xsignature',
    });
    expect(status.isVerified, isTrue);
    expect(status.credential, 'orb');
  });
}
