// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITransactionGuard} from "./interfaces/ITransactionGuard.sol";

contract Chapter2Guard is ITransactionGuard {
    address public owner;
    address public safeAddress;
    address public autonomousAgent;
    address public humanSigner;

    error OnlyOwner();
    error OnlySafe();

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
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external virtual override onlySafe {}

    function checkAfterExecution(bytes32 txHash, bool success) external virtual override onlySafe {}

    function setAutonomousAgent(address _agent) external onlyOwner {
        autonomousAgent = _agent;
    }

    function setHumanSigner(address _signer) external onlyOwner {
        humanSigner = _signer;
    }
}
