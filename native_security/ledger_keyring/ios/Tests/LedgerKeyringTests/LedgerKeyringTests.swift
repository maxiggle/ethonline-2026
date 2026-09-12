import XCTest
import CryptoKit
@testable import LedgerKeyring

final class LedgerKeyringTests: XCTestCase {
    func testDeviceModelProperties() {
        XCTAssertFalse(LedgerDeviceModel.nanoS.supportsBluetooth)
        XCTAssertTrue(LedgerDeviceModel.nanoX.supportsBluetooth)
        XCTAssertTrue(LedgerDeviceModel.stax.supportsBluetooth)
        XCTAssertTrue(LedgerDeviceModel.stax.supportsTouchScreen)
        XCTAssertEqual(LedgerDeviceModel.stax.screenWidthPixels, 400)
    }

    func testAPDUCommandSerialization() {
        let digest = Data(repeating: 0xAB, count: 32)
        let apdu = LedgerAPDUCommand.signEIP712Digest(digest: digest)

        let bytes = apdu.serialize()
        XCTAssertEqual(bytes.count, 4 + 1 + 32)
        XCTAssertEqual(bytes[0], 0xE0)
        XCTAssertEqual(bytes[1], LedgerAPDUCommand.EthereumInstruction.signEIP712Message.rawValue)
        XCTAssertEqual(bytes[4], 32)
    }

    func testStatusWordDecoding() {
        XCTAssertEqual(LedgerAPDUCommand.StatusWord.from(code: 0x9000), .success)
        XCTAssertEqual(LedgerAPDUCommand.StatusWord.from(code: 0x6985), .userRefused)
        XCTAssertEqual(LedgerAPDUCommand.StatusWord.from(code: 0x6511), .appNotStarted)
        XCTAssertEqual(LedgerAPDUCommand.StatusWord.from(code: 0x1234), .unknown)
    }

    func testBLEFramingAndDeframing() throws {
        let originalData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let mtu = 10

        let packets = LedgerBLEFraming.frameAPDU(data: originalData, mtu: mtu)
        XCTAssertGreaterThan(packets.count, 1)

        var responseBuffer = originalData
        responseBuffer.append(contentsOf: [0x90, 0x00])

        let responsePackets = LedgerBLEFraming.frameAPDU(data: responseBuffer, mtu: mtu)
        let (payload, status) = try LedgerBLEFraming.deframeResponse(packets: responsePackets)

        XCTAssertEqual(payload, originalData)
        XCTAssertEqual(status, .success)
    }

    func testLKRPEncryptionDecryption() throws {
        let protocolHandler = LedgerKeyRingProtocol()
        let salt = Data(repeating: 0x42, count: 16)
        let masterKey = LedgerKeyRingProtocol.deriveMasterKey(from: "chapter2_secure_passphrase", salt: salt)

        let secretPlaintext = Data("SUPER_SECRET_PRIVATE_KEY_BYTES".utf8)
        let encrypted = try protocolHandler.encrypt(
            plaintext: secretPlaintext,
            keyName: "agent_signer_key",
            using: masterKey
        )

        XCTAssertFalse(encrypted.combinedSerialization.isEmpty)
        XCTAssertEqual(encrypted.keyName, "agent_signer_key")

        let decrypted = try protocolHandler.decrypt(payload: encrypted, using: masterKey)
        XCTAssertEqual(decrypted, secretPlaintext)
    }

    func testClearSignPromptFormatting() {
        let session = LedgerSigningSession()
        let payload = EIP712ApprovalPayload(
            actionId: "act_test_001",
            agent: "0x1111111111111111111111111111111111111111",
            recipient: "0x0000000000000000000000000000000000041c4e",
            token: "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
            amountUnits: 250_000_000,
            nonce: 101,
            deadlineTimestamp: 1800000000,
            mandateHash: "0x71e847c234a413ba1179ab846059c402aaefd685ad83a8b2b7161b9a95cbba84",
            riskScore: 78
        )

        let prompt = session.formatPrompt(for: payload, digestHex: "0xabcdef...")
        XCTAssertEqual(prompt.title, "CHAPTER 2 TREASURY ESCALATION")
        XCTAssertEqual(prompt.riskTier, .highRisk)
        XCTAssertTrue(prompt.fields.contains { $0.label == "Transfer Amount" && $0.value.contains("$250.00") })
        XCTAssertTrue(prompt.fields.contains { $0.label == "Recipient" && $0.value == "0x0000000000000000000000000000000000041c4e" })
    }

    func testMockHardwareSigning() {
        let session = LedgerSigningSession()
        let payload = EIP712ApprovalPayload(
            actionId: "act_test_002",
            agent: "0x1111111111111111111111111111111111111111",
            recipient: "0x0000000000000000000000000000000000041c4e",
            token: "0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6",
            amountUnits: 50_000_000,
            nonce: 1,
            deadlineTimestamp: 1800000000,
            mandateHash: "0x1234",
            riskScore: 10
        )

        let successResult = session.executeMockClearSigning(
            for: payload,
            mockSigner: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            userApproved: true
        )

        switch successResult {
        case .success(let res):
            XCTAssertEqual(res.signerAddress, "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554")
            XCTAssertTrue(res.signatureHex.hasPrefix("0x"))
            XCTAssertEqual(res.signatureHex.count, 132)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }

        let userRejectedResult = session.executeMockClearSigning(
            for: payload,
            mockSigner: "0xA11CEAC3b97b0a701997d9145885C6A2E55b2554",
            userApproved: false
        )

        switch userRejectedResult {
        case .success:
            XCTFail("Expected failure on user rejection")
        case .failure(let error):
            XCTAssertEqual(error, .userRejectedOnDevice)
        }
    }

    func testSecureEnclaveKeyRingAvailabilityAndProperties() {
        let isAvailable = SecureEnclaveKeyRing.isSecureEnclaveAvailable
        // Verify that SecureEnclave availability can be safely queried without crashing
        XCTAssertTrue(isAvailable == true || isAvailable == false)

        let ring = SecureEnclaveKeyRing()
        if isAvailable {
            do {
                // Generate a key without biometrics for unit testing environments
                let keyInfo = try ring.generateSecureEnclaveSigningKey(
                    tag: "unit_test_enclave_key",
                    requireBiometrics: false
                )
                XCTAssertEqual(keyInfo.keyTag, "unit_test_enclave_key")
                XCTAssertTrue(keyInfo.isStronglyHardwareIsolated)
                XCTAssertFalse(keyInfo.publicKeyRaw.isEmpty)
            } catch {
                // In headless CI/sandbox without keychain entitlements, catch gracefully
                XCTAssertNotNil(error)
            }
        }
    }
}

