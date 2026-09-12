import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { ActionStoreService } from '../actions/action-store.service';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';

export interface PaymentRequirements {
  address: string;
  amount: string;
  token: string;
  chainId: number;
}

export interface ComputeResourceGrant {
  status: 'UNLOCKED';
  resource: string;
  txHash: string;
  sessionToken: string;
  message: string;
  expiresAt: string;
  details: {
    specs: string;
    cluster: string;
    allocatedVramGb: number;
  };
}

@Injectable()
export class VendorService {
  private readonly logger = new Logger(VendorService.name);

  // Approved Vendor Recipient from Chapter 2 mandate
  public readonly vendorAddress = '0x0000000000000000000000000000000000041c4e';
  public readonly tokenAddress: string;
  public readonly requiredAmount = '40000000'; // 40 USDC (6 decimals)
  public readonly chainId: number;

  constructor(
    private readonly onChainExecutor: OnChainExecutorService,
    private readonly actionStore: ActionStoreService,
  ) {
    const safeAddress = process.env.SAFE_ADDRESS;
    if (!safeAddress) {
      throw new Error('Missing required environment variable: SAFE_ADDRESS');
    }

    const chainId = process.env.CHAIN_ID;
    if (!chainId) {
      throw new Error('Missing required environment variable: CHAIN_ID');
    }

    this.tokenAddress = safeAddress;
    this.chainId = Number(chainId);
  }

  getPaymentRequirements(): PaymentRequirements {
    return {
      address: this.vendorAddress,
      amount: this.requiredAmount,
      token: this.tokenAddress,
      chainId: this.chainId,
    };
  }

  async verifyAndGrantAccess(txHash: string): Promise<ComputeResourceGrant> {
    if (!txHash || !txHash.startsWith('0x')) {
      throw new BadRequestException(`Malformed X-Payment-TxHash: '${txHash}'`);
    }

    // 1. Check Action Store for executed action
    const allActions = this.actionStore.listActions();
    const action = allActions.find((a) => a.txHash?.toLowerCase() === txHash.toLowerCase());

    if (action) {
      if (action.status !== TreasuryActionStatus.EXECUTED && action.status !== TreasuryActionStatus.APPROVED) {
        throw new BadRequestException(
          `Payment transaction is in invalid status: ${action.status}. Must be EXECUTED or APPROVED.`,
        );
      }

      if (action.recipient.toLowerCase() !== this.vendorAddress.toLowerCase()) {
        throw new BadRequestException(
          `Payment recipient mismatch: paid to ${action.recipient}, required ${this.vendorAddress}`,
        );
      }

      if (BigInt(action.amount) < BigInt(this.requiredAmount)) {
        throw new BadRequestException(
          `Insufficient payment amount: received ${action.amount}, required ${this.requiredAmount}`,
        );
      }
    } else {
      // 2. Fallback to on-chain verification
      const verifyResult = await this.onChainExecutor.verifyTransaction(txHash);
      if (!verifyResult.verified) {
        throw new BadRequestException(
          `On-chain payment verification failed: ${verifyResult.error || 'Transaction unconfirmed'}`,
        );
      }
    }

    this.logger.log(`x402 Payment verified for tx ${txHash}. Unlocking compute session.`);

    const now = Date.now();
    return {
      status: 'UNLOCKED',
      resource: 'compute:dedicated-cluster:h100-gpu-node-01',
      txHash,
      sessionToken: `sess_${now}_${txHash.substring(2, 10)}`,
      message: 'x402 payment successfully settled on-chain. Compute resource unlocked.',
      expiresAt: new Date(now + 3600 * 1000).toISOString(),
      details: {
        specs: '1x NVIDIA H100 Tensor Core GPU (80GB SXM5)',
        cluster: 'base-sepolia-autonomous-compute-pool-01',
        allocatedVramGb: 80,
      },
    };
  }
}
