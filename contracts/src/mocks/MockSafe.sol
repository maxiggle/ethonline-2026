// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISafe} from "../interfaces/ISafe.sol";
import {ITransactionGuard} from "../interfaces/ITransactionGuard.sol";

contract MockSafe is ISafe {
    address public guard;
    address public owner;
    uint256 public nonce;

    event ExecutionSuccess(bytes32 txHash, uint256 payment);
    event ExecutionFailure(bytes32 txHash, uint256 payment);
    event ChangedGuard(address guard);

    modifier onlyOwner() {
        require(msg.sender == owner, "MockSafe: Caller is not owner");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    receive() external payable {}

    function setGuard(address _guard) external override {
        require(msg.sender == owner || msg.sender == address(this), "MockSafe: Not authorized");
        guard = _guard;
        emit ChangedGuard(_guard);
    }

    function getGuard() external view override returns (address) {
        return guard;
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable override returns (bool success) {
        bytes32 txHash = keccak256(
            abi.encodePacked(
                to,
                value,
                keccak256(data),
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                nonce++
            )
        );

        if (guard != address(0)) {
            ITransactionGuard(guard).checkTransaction(
                to,
                value,
                data,
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                signatures,
                msg.sender
            );
        }

        (success, ) = to.call{value: value}(data);

        if (guard != address(0)) {
            ITransactionGuard(guard).checkAfterExecution(txHash, success);
        }

        if (success) {
            emit ExecutionSuccess(txHash, 0);
        } else {
            emit ExecutionFailure(txHash, 0);
        }
    }
}
