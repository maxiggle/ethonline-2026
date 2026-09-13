import 'package:chapter2/features/world_id/remote/models/world_id_approver_status.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorldIdOrbVerificationStatus', () {
    test('round-trips all valid status strings', () {
      final expected = {
        'WAITING_FOR_WORLD_APP': WorldIdOrbVerificationStatus.waitingForWorldApp,
        'AWAITING_CONFIRMATION': WorldIdOrbVerificationStatus.awaitingConfirmation,
        'VERIFIED': WorldIdOrbVerificationStatus.verified,
        'BOUND': WorldIdOrbVerificationStatus.bound,
        'FAILED': WorldIdOrbVerificationStatus.failed,
        'EXPIRED': WorldIdOrbVerificationStatus.expired,
      };

      for (final entry in expected.entries) {
        expect(WorldIdOrbVerificationStatus.fromString(entry.key), entry.value);
        expect(entry.value.value, entry.key);
      }
    });

    test('throws FormatException on unknown status string', () {
      expect(
        () => WorldIdOrbVerificationStatus.fromString('UNKNOWN_STATUS'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WorldIdOrbVerificationStatus.fromString(''),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WorldIdApproverStatus', () {
    test('parses full json payload correctly', () {
      final json = {
        'approverAddress': '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        'isWorldIdRequired': true,
        'isWorldIdConfigured': true,
        'environment': 'staging',
        'isVerified': true,
        'credential': 'orb',
        'boundAt': '2026-09-13T10:00:00.000Z',
        'expiresAt': '2026-12-12T10:00:00.000Z',
      };

      final status = WorldIdApproverStatus.fromJson(json);
      expect(status.approverAddress, '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6');
      expect(status.isWorldIdRequired, isTrue);
      expect(status.isWorldIdConfigured, isTrue);
      expect(status.environment, 'staging');
      expect(status.isVerified, isTrue);
      expect(status.credential, 'orb');
      expect(status.boundAt, DateTime.parse('2026-09-13T10:00:00.000Z'));
      expect(status.expiresAt, DateTime.parse('2026-12-12T10:00:00.000Z'));
    });

    test('parses unverified/unbound status with null dates', () {
      final json = {
        'approverAddress': '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        'isWorldIdRequired': false,
        'isWorldIdConfigured': false,
        'environment': null,
        'isVerified': false,
        'credential': null,
        'boundAt': null,
        'expiresAt': null,
      };

      final status = WorldIdApproverStatus.fromJson(json);
      expect(status.isWorldIdRequired, isFalse);
      expect(status.isWorldIdConfigured, isFalse);
      expect(status.isVerified, isFalse);
      expect(status.boundAt, isNull);
      expect(status.expiresAt, isNull);
    });
  });

  group('WorldIdOrbVerification', () {
    test('parses active verification payload', () {
      final json = {
        'requestId': 'req-1234',
        'status': 'WAITING_FOR_WORLD_APP',
        'connectorUrl': 'https://worldcoin.org/verify?t=test',
        'expiresAt': '2026-09-13T10:15:00.000Z',
        'bindMessage': null,
        'errorMessage': null,
      };

      final verification = WorldIdOrbVerification.fromJson(json);
      expect(verification.requestId, 'req-1234');
      expect(verification.status, WorldIdOrbVerificationStatus.waitingForWorldApp);
      expect(verification.connectorUrl, 'https://worldcoin.org/verify?t=test');
      expect(verification.expiresAt, DateTime.parse('2026-09-13T10:15:00.000Z'));
      expect(verification.bindMessage, isNull);
      expect(verification.errorMessage, isNull);
    });

    test('parses verified state with bindMessage', () {
      final json = {
        'requestId': 'req-1234',
        'status': 'VERIFIED',
        'connectorUrl': null,
        'expiresAt': '2026-09-13T10:15:00.000Z',
        'bindMessage': 'chapter2-world-bind:0xnullifier',
        'errorMessage': null,
      };

      final verification = WorldIdOrbVerification.fromJson(json);
      expect(verification.status, WorldIdOrbVerificationStatus.verified);
      expect(verification.bindMessage, 'chapter2-world-bind:0xnullifier');
    });

    test('parses failed state with error message', () {
      final json = {
        'requestId': 'req-1234',
        'status': 'FAILED',
        'connectorUrl': null,
        'expiresAt': '2026-09-13T10:15:00.000Z',
        'bindMessage': null,
        'errorMessage': 'Nullifier bound to another signer',
      };

      final verification = WorldIdOrbVerification.fromJson(json);
      expect(verification.status, WorldIdOrbVerificationStatus.failed);
      expect(verification.errorMessage, 'Nullifier bound to another signer');
    });
  });
}
