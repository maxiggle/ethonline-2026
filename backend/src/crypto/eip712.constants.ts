import { Eip712Domain, Eip712TypeProperty } from './interfaces/eip712.interface';

export const ACTION_APPROVAL_PRIMARY_TYPE = 'TreasuryActionApproval';

export const ACTION_APPROVAL_TYPE_STRING =
  'TreasuryActionApproval(string actionId,address agent,address recipient,address token,uint256 amount,uint256 nonce,uint256 deadline,bytes32 mandateHash,uint8 riskScore)';

export const EIP712_ACTION_APPROVAL_TYPES: Record<string, Eip712TypeProperty[]> = {
  TreasuryActionApproval: [
    { name: 'actionId', type: 'string' },
    { name: 'agent', type: 'address' },
    { name: 'recipient', type: 'address' },
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
    { name: 'mandateHash', type: 'bytes32' },
    { name: 'riskScore', type: 'uint8' },
  ],
};

export const DEFAULT_BASE_SEPOLIA_DOMAIN: Eip712Domain = {
  name: 'Chapter2',
  version: '1',
  chainId: 84532,
  verifyingContract: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
};

export const ESCALATED_ACTION_APPROVAL_ABI_TYPE =
  'tuple(string actionId, address agent, address recipient, address token, uint256 amount, uint256 nonce, uint256 deadline, bytes32 mandateHash, uint8 riskScore)';
