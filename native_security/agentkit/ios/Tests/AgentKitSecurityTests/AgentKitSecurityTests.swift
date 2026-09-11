import XCTest
@testable import AgentKitSecurity

final class AgentKitSecurityTests: XCTestCase {
    func testCredentialTypeParsing() {
        XCTAssertEqual(WorldIdCredentialType.from(raw: "11"), .credential11Selfie)
        XCTAssertEqual(WorldIdCredentialType.from(raw: "selfie"), .credential11Selfie)
        XCTAssertEqual(WorldIdCredentialType.from(raw: "orb"), .orb)
        XCTAssertEqual(WorldIdCredentialType.from(raw: "device"), .device)

        XCTAssertTrue(WorldIdCredentialType.credential11Selfie.isBiometricVerified)
        XCTAssertTrue(WorldIdCredentialType.orb.isBiometricVerified)
        XCTAssertFalse(WorldIdCredentialType.device.isBiometricVerified)
    }

    func testValidSelfieProofValidation() {
        let coordinator = SelfieLivenessCaptureCoordinator()
        let proof = WorldIdProofPayload(
            merkleRoot: "0x1234",
            nullifierHash: "0xnullifier",
            proof: "0xproofbytes",
            credentialType: .credential11Selfie,
            action: "chapter2_human_verification",
            signal: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554"
        )

        let result = coordinator.validateSelfieProof(
            proof: proof,
            expectedSigner: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            expectedAction: "chapter2_human_verification"
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected valid proof but got error: \(error)")
        }
    }

    func testRejectWeakDeviceOnlyProof() {
        let coordinator = SelfieLivenessCaptureCoordinator()
        let proof = WorldIdProofPayload(
            merkleRoot: "0x1234",
            nullifierHash: "0xnullifier",
            proof: "0xproofbytes",
            credentialType: .device,
            action: "chapter2_human_verification",
            signal: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554"
        )

        let result = coordinator.validateSelfieProof(
            proof: proof,
            expectedSigner: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            expectedAction: "chapter2_human_verification"
        )

        switch result {
        case .success:
            XCTFail("Expected failure on weak device-only credential")
        case .failure(let error):
            XCTAssertEqual(error, .weakCredentialRejected(credential: .device))
        }
    }

    func testRejectSignalMismatch() {
        let coordinator = SelfieLivenessCaptureCoordinator()
        let proof = WorldIdProofPayload(
            merkleRoot: "0x1234",
            nullifierHash: "0xnullifier",
            proof: "0xproofbytes",
            credentialType: .credential11Selfie,
            action: "chapter2_human_verification",
            signal: "0xATTACKER00000000000000000000000000000002"
        )

        let result = coordinator.validateSelfieProof(
            proof: proof,
            expectedSigner: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            expectedAction: "chapter2_human_verification"
        )

        switch result {
        case .success:
            XCTFail("Expected failure on signal mismatch")
        case .failure(let error):
            XCTAssertEqual(
                error,
                .signalMismatch(
                    expected: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
                    actual: "0xATTACKER00000000000000000000000000000002"
                )
            )
        }
    }

    func testSignerBinding90DayWindowAndTouch() {
        let now = Date()
        var binding = WorldIdSignerBinding(
            signerAddress: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            nullifierHash: "0xnullifier_001",
            credentialType: .credential11Selfie,
            boundAt: now,
            lastActiveAt: now
        )

        XCTAssertTrue(binding.isValid(at: now))

        // Check after 45 days (still valid)
        let day45 = now.addingTimeInterval(45 * 24 * 3600)
        XCTAssertTrue(binding.isValid(at: day45))

        // Check after 91 days (expired)
        let day91 = now.addingTimeInterval(91 * 24 * 3600)
        XCTAssertFalse(binding.isValid(at: day91))

        // Touch activity refreshes the 90-day window
        binding.touchActivity(at: day45)
        XCTAssertTrue(binding.isValid(at: day91))
    }

    func testAgentKitSecurityGuardDecisions() {
        let guardService = AgentKitSecurityGuard()
        let now = Date()
        let binding = WorldIdSignerBinding(
            signerAddress: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            nullifierHash: "0xnullifier_001",
            credentialType: .credential11Selfie,
            boundAt: now,
            lastActiveAt: now
        )

        // Autonomous transfer under $100 -> ALLOW
        let allowRes = guardService.evaluateAgentAction(
            amountUnits: 50_000_000,
            maxAutonomousCap: 100_000_000,
            humanBinding: binding,
            currentDate: now
        )
        XCTAssertEqual(allowRes, .success(.autonomousAllow))

        // Transfer over $100 with valid human binding -> ESCALATE
        let escalateRes = guardService.evaluateAgentAction(
            amountUnits: 250_000_000,
            maxAutonomousCap: 100_000_000,
            humanBinding: binding,
            currentDate: now
        )
        switch escalateRes {
        case .success(let decision):
            guard case .escalateToBiometricHumanApproval = decision else {
                return XCTFail("Expected escalate decision")
            }
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        // Transfer over $100 without human binding -> FAIL
        let noBindingRes = guardService.evaluateAgentAction(
            amountUnits: 250_000_000,
            maxAutonomousCap: 100_000_000,
            humanBinding: nil,
            currentDate: now
        )
        XCTAssertEqual(noBindingRes, .failure(.autonomousLimitExceeded(amount: 250_000_000, maxAutonomousCap: 100_000_000)))
    }
}
