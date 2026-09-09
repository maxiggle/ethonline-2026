// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITransactionGuard} from "./interfaces/ITransactionGuard.sol";

contract Chapter2Guard is ITransactionGuard {
    bytes4 private constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    address public owner;
    address public safeAddress;
    address public autonomousAgent;
    address public humanSigner;

    mapping(address => bool) public isApprovedRecipient;

    event RecipientStatusUpdated(address indexed recipient, bool approved);

    error OnlyOwner();
    error OnlySafe();
    error RecipientNotApproved(address recipient);
    error InvalidData();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlySafe() {
        if (msg.sender != safeAddress) revert OnlySafe();
        _;
    }

    constructor(
        address _owner,
        address _safeAddress,
        address _autonomousAgent,
        address _humanSigner
    ) {
        owner = _owner;
        safeAddress = _safeAddress;
        autonomousAgent = _autonomousAgent;
        humanSigner = _humanSigner;
    }

    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        uint8,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address msgSender
    ) external virtual override onlySafe {
        if (msgSender == owner) {
            return;
        }

        address recipient;

        if (data.length >= 68 && bytes4(data) == ERC20_TRANSFER_SELECTOR) {
            (recipient, ) = abi.decode(_slice(data, 4, 64), (address, uint256));
        } else if (value > 0 && data.length == 0) {
            recipient = to;
        } else {
            revert InvalidData();
        }

        if (!isApprovedRecipient[recipient]) {
            revert RecipientNotApproved(recipient);
        }
    }

    function checkAfterExecution(bytes32, bool) external virtual override onlySafe {}

    function setApprovedRecipient(address recipient, bool approved) external onlyOwner {
        isApprovedRecipient[recipient] = approved;
        emit RecipientStatusUpdated(recipient, approved);
    }

    function setAutonomousAgent(address _agent) external onlyOwner {
        autonomousAgent = _agent;
    }

    function setHumanSigner(address _signer) external onlyOwner {
        humanSigner = _signer;
    }

    function _slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory part = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            part[i] = data[start + i];
        }
        return part;
    }
}
