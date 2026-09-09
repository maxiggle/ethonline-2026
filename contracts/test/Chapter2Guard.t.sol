// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Chapter2Guard} from "../src/Chapter2Guard.sol";
import {MockSafe} from "../src/mocks/MockSafe.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract Chapter2GuardTest is Test {
    Chapter2Guard public guard;
    MockSafe public safe;

    uint256 internal humanPrivateKey = 0xA11CE;
    address internal humanOwner;
    address internal agent = address(0x2);
    address internal alchemyRecipient = address(uint160(0x41C4E));
    address internal unknownAttacker = address(uint160(0x8F0000000000000000000000000000000000072A));

    function setUp() public {
        humanOwner = vm.addr(humanPrivateKey);
        safe = new MockSafe(humanOwner);
        guard = new Chapter2Guard(humanOwner, address(safe), agent, humanOwner, 100 * 1e6, 500 * 1e6);

        vm.prank(humanOwner);
        safe.setGuard(address(guard));

        vm.prank(humanOwner);
        guard.setApprovedRecipient(alchemyRecipient, true);

        vm.prank(humanOwner);
        guard.setApprovedToken(address(0x999), true);
    }

    function test_RevertWhen_RecipientNotApproved() public {
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            unknownAttacker,
            5_000 * 1e6
        );

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(Chapter2Guard.RecipientNotApproved.selector, unknownAttacker)
        );
        safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            ""
        );
    }

    function test_AllowWhen_RecipientIsApproved() public {
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            40 * 1e6
        );

        vm.prank(agent);
        bool success = safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            ""
        );
        assertTrue(success);
    }

    function test_RevertWhen_AutonomousPaymentExceedsLimit() public {
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            850 * 1e6
        );

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(Chapter2Guard.ExceedsAutonomousLimit.selector, 850 * 1e6, 100 * 1e6)
        );
        safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            ""
        );
    }

    function test_AllowWhen_OwnerBypassesAutonomousLimit() public {
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            5_000 * 1e6
        );

        vm.prank(humanOwner);
        bool success = safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            ""
        );
        assertTrue(success);
    }

    function test_DailyLimitEnforcement_AndRollover() public {
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            100 * 1e6
        );

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(agent);
            safe.execTransaction(
                address(0x999),
                0,
                transferData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                ""
            );
        }

        assertEq(guard.getRemainingDailyBudget(), 0);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(Chapter2Guard.ExceedsDailyLimit.selector, 600 * 1e6, 500 * 1e6)
        );
        safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            ""
        );

        vm.warp(block.timestamp + 1 days);
        assertEq(guard.getRemainingDailyBudget(), 500 * 1e6);

        vm.prank(agent);
        bool successAfterWarp = safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            ""
        );
        assertTrue(successAfterWarp);
    }

    function test_AllowWhen_EscalatedPaymentSignedByHumanLedger() public {
        uint256 suspiciousAmount = 850 * 1e6;
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            suspiciousAmount
        );

        Chapter2Guard.TreasuryActionApproval memory approval = Chapter2Guard.TreasuryActionApproval({
            actionId: "act_alchemy_annual_renewal_001",
            agent: agent,
            recipient: alchemyRecipient,
            token: address(0x999),
            amount: suspiciousAmount,
            nonce: 101,
            deadline: block.timestamp + 1 hours,
            mandateHash: keccak256("MANDATE_V1"),
            riskScore: 78
        });

        bytes32 structHash = keccak256(
            abi.encode(
                guard.ACTION_APPROVAL_TYPEHASH(),
                keccak256(bytes(approval.actionId)),
                approval.agent,
                approval.recipient,
                approval.token,
                approval.amount,
                approval.nonce,
                approval.deadline,
                approval.mandateHash,
                approval.riskScore
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", guard.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(humanPrivateKey, digest);
        bytes memory signaturePayload = abi.encode(approval, abi.encodePacked(r, s, v));

        vm.prank(agent);
        bool success = safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signaturePayload
        );
        assertTrue(success);
    }

    function test_RevertWhen_EscalatedPaymentHasInvalidSigner() public {
        uint256 suspiciousAmount = 850 * 1e6;
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            suspiciousAmount
        );

        Chapter2Guard.TreasuryActionApproval memory approval = Chapter2Guard.TreasuryActionApproval({
            actionId: "act_fraud_attempt",
            agent: agent,
            recipient: alchemyRecipient,
            token: address(0x999),
            amount: suspiciousAmount,
            nonce: 102,
            deadline: block.timestamp + 1 hours,
            mandateHash: keccak256("MANDATE_V1"),
            riskScore: 78
        });

        bytes32 structHash = keccak256(
            abi.encode(
                guard.ACTION_APPROVAL_TYPEHASH(),
                keccak256(bytes(approval.actionId)),
                approval.agent,
                approval.recipient,
                approval.token,
                approval.amount,
                approval.nonce,
                approval.deadline,
                approval.mandateHash,
                approval.riskScore
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", guard.DOMAIN_SEPARATOR(), structHash)
        );

        uint256 unauthorizedKey = 0xDEAD;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedKey, digest);
        bytes memory signaturePayload = abi.encode(approval, abi.encodePacked(r, s, v));

        vm.prank(agent);
        vm.expectRevert(Chapter2Guard.InvalidSignature.selector);
        safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signaturePayload
        );
    }

    function test_RevertWhen_EscalatedPaymentReplaysNonce() public {
        uint256 suspiciousAmount = 850 * 1e6;
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            alchemyRecipient,
            suspiciousAmount
        );

        Chapter2Guard.TreasuryActionApproval memory approval = Chapter2Guard.TreasuryActionApproval({
            actionId: "act_alchemy_replay_test",
            agent: agent,
            recipient: alchemyRecipient,
            token: address(0x999),
            amount: suspiciousAmount,
            nonce: 202,
            deadline: block.timestamp + 1 hours,
            mandateHash: keccak256("MANDATE_V1"),
            riskScore: 78
        });

        bytes32 structHash = keccak256(
            abi.encode(
                guard.ACTION_APPROVAL_TYPEHASH(),
                keccak256(bytes(approval.actionId)),
                approval.agent,
                approval.recipient,
                approval.token,
                approval.amount,
                approval.nonce,
                approval.deadline,
                approval.mandateHash,
                approval.riskScore
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", guard.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(humanPrivateKey, digest);
        bytes memory signaturePayload = abi.encode(approval, abi.encodePacked(r, s, v));

        vm.prank(agent);
        bool firstExecution = safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signaturePayload
        );
        assertTrue(firstExecution);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(Chapter2Guard.NonceAlreadyUsed.selector, approval.nonce)
        );
        safe.execTransaction(
            address(0x999),
            0,
            transferData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signaturePayload
        );
    }
}
