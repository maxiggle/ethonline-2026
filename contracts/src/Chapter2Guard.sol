// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITransactionGuard} from "./interfaces/ITransactionGuard.sol";

contract Chapter2Guard is ITransactionGuard {
    bytes4 private constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant ACTION_APPROVAL_TYPEHASH =
        keccak256(
            "TreasuryActionApproval(string actionId,address agent,address recipient,address token,uint256 amount,uint256 nonce,uint256 deadline,bytes32 mandateHash,uint8 riskScore)"
        );

    address public owner;
    address public safeAddress;
    address public autonomousAgent;
    address public humanSigner;
    uint256 public maxAutonomousAmount;
    uint256 public dailyAutonomousLimit;

    mapping(uint256 => uint256) public dailySpent;
    mapping(address => bool) public isApprovedRecipient;
    mapping(address => bool) public isApprovedToken;

    struct TreasuryActionApproval {
        string actionId;
        address agent;
        address recipient;
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
        bytes32 mandateHash;
        uint8 riskScore;
    }

    event AutonomousActionExecuted(
        address indexed agent,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 dailySpentTotal
    );
    event RecipientStatusUpdated(address indexed recipient, bool approved);
    event TokenStatusUpdated(address indexed token, bool approved);
    event MaxAutonomousAmountUpdated(uint256 maxLimit);
    event DailyAutonomousLimitUpdated(uint256 dailyLimit);

    error OnlyOwner();
    error OnlySafe();
    error RecipientNotApproved(address recipient);
    error TokenNotApproved(address token);
    error ExceedsAutonomousLimit(uint256 requested, uint256 maxLimit);
    error ExceedsDailyLimit(uint256 currentDaily, uint256 maxDaily);
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
        address _humanSigner,
        uint256 _maxAutonomousAmount,
        uint256 _dailyAutonomousLimit
    ) {
        owner = _owner;
        safeAddress = _safeAddress;
        autonomousAgent = _autonomousAgent;
        humanSigner = _humanSigner;
        maxAutonomousAmount = _maxAutonomousAmount;
        dailyAutonomousLimit = _dailyAutonomousLimit;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Chapter2")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
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
        uint256 amount;
        address token;

        if (data.length >= 68 && bytes4(data) == ERC20_TRANSFER_SELECTOR) {
            token = to;
            if (!isApprovedToken[token]) {
                revert TokenNotApproved(token);
            }
            (recipient, amount) = abi.decode(_slice(data, 4, 64), (address, uint256));
        } else if (value > 0 && data.length == 0) {
            token = address(0);
            recipient = to;
            amount = value;
        } else {
            revert InvalidData();
        }

        if (!isApprovedRecipient[recipient]) {
            revert RecipientNotApproved(recipient);
        }

        if (msgSender == autonomousAgent) {
            if (amount > maxAutonomousAmount) {
                revert ExceedsAutonomousLimit(amount, maxAutonomousAmount);
            }

            uint256 dayId = block.timestamp / 1 days;
            uint256 newDailyTotal = dailySpent[dayId] + amount;

            if (newDailyTotal > dailyAutonomousLimit) {
                revert ExceedsDailyLimit(newDailyTotal, dailyAutonomousLimit);
            }

            dailySpent[dayId] = newDailyTotal;
            emit AutonomousActionExecuted(autonomousAgent, recipient, token, amount, newDailyTotal);
        }
    }

    function checkAfterExecution(bytes32, bool) external virtual override onlySafe {}

    function setApprovedRecipient(address recipient, bool approved) external onlyOwner {
        isApprovedRecipient[recipient] = approved;
        emit RecipientStatusUpdated(recipient, approved);
    }

    function setApprovedToken(address token, bool approved) external onlyOwner {
        isApprovedToken[token] = approved;
        emit TokenStatusUpdated(token, approved);
    }

    function updateMandateLimits(uint256 _maxPerTx, uint256 _dailyLimit) external onlyOwner {
        maxAutonomousAmount = _maxPerTx;
        dailyAutonomousLimit = _dailyLimit;
        emit MaxAutonomousAmountUpdated(_maxPerTx);
        emit DailyAutonomousLimitUpdated(_dailyLimit);
    }

    function setAutonomousAgent(address _agent) external onlyOwner {
        autonomousAgent = _agent;
    }

    function setHumanSigner(address _signer) external onlyOwner {
        humanSigner = _signer;
    }

    function getRemainingDailyBudget() external view returns (uint256) {
        uint256 dayId = block.timestamp / 1 days;
        uint256 spent = dailySpent[dayId];
        if (spent >= dailyAutonomousLimit) {
            return 0;
        }
        return dailyAutonomousLimit - spent;
    }

    function _slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory part = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            part[i] = data[start + i];
        }
        return part;
    }
}
