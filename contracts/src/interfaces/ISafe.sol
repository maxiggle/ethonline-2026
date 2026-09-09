// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISafe {
    function setGuard(address guard) external;
    function getGuard() external view returns (address);
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
    ) external payable returns (bool success);
}
