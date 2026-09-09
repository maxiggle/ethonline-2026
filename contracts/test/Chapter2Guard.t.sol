// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Chapter2Guard} from "../src/Chapter2Guard.sol";
import {MockSafe} from "../src/mocks/MockSafe.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract Chapter2GuardTest is Test {
    Chapter2Guard public guard;
    MockSafe public safe;

    address internal humanOwner = address(0x1);
    address internal agent = address(0x2);
    address internal alchemyRecipient = address(uint160(0x41C4E));
    address internal unknownAttacker = address(uint160(0x8F0000000000000000000000000000000000072A));

    function setUp() public {
        safe = new MockSafe(humanOwner);
        guard = new Chapter2Guard(humanOwner, address(safe), agent, humanOwner);

        vm.prank(humanOwner);
        safe.setGuard(address(guard));

        vm.prank(humanOwner);
        guard.setApprovedRecipient(alchemyRecipient, true);
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
}
