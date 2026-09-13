import { Injectable, Logger } from '@nestjs/common';
import { JsonRpcProvider, Contract, Interface, getAddress, TransactionReceipt, formatEther } from 'ethers';

const SAFE_ABI = [
  'function getGuard() external view returns (address)',
  'function nonce() external view returns (uint256)',
  'function owner() external view returns (address)',
];

const GUARD_ABI = [
  'function maxAutonomousAmount() external view returns (uint256)',
  'function dailyAutonomousLimit() external view returns (uint256)',
  'function getRemainingDailyBudget() external view returns (uint256)',
  'function safeAddress() external view returns (address)',
  'function autonomousAgent() external view returns (address)',
  'function isApprovedRecipient(address recipient) external view returns (bool)',
  'function isApprovedToken(address token) external view returns (bool)',
];

const ERC20_ABI = [
  'function balanceOf(address account) external view returns (uint256)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
];

const ERC20_TRANSFER_EVENT_INTERFACE = new Interface([
  'event Transfer(address indexed from, address indexed to, uint256 value)',
]);

/**
 * Read-only access to Base Sepolia: settlement verification, contract state and treasury balances.
 * The backend holds no signing key, so it can never broadcast a transaction.
 */
@Injectable()
export class OnChainExecutorService {
  private readonly logger = new Logger(OnChainExecutorService.name);
  public readonly provider: JsonRpcProvider;
  public readonly safeContract: Contract;
  public readonly guardContract: Contract;

  public readonly rpcUrl: string;
  public readonly safeAddress: string;
  public readonly guardAddress: string;
  public readonly chainId: number;

  constructor() {
    const rpcUrl = process.env.RPC_URL;
    if (!rpcUrl) {
      throw new Error('Missing required environment variable: RPC_URL');
    }

    const safeAddress = process.env.SAFE_ADDRESS;
    if (!safeAddress) {
      throw new Error('Missing required environment variable: SAFE_ADDRESS');
    }

    const guardAddress = process.env.GUARD_ADDRESS;
    if (!guardAddress) {
      throw new Error('Missing required environment variable: GUARD_ADDRESS');
    }

    const chainId = process.env.CHAIN_ID;
    if (!chainId) {
      throw new Error('Missing required environment variable: CHAIN_ID');
    }

    this.rpcUrl = rpcUrl;
    this.safeAddress = getAddress(safeAddress);
    this.guardAddress = getAddress(guardAddress);
    this.chainId = Number(chainId);

    this.provider = new JsonRpcProvider(this.rpcUrl, this.chainId, {
      staticNetwork: true,
    });
    this.safeContract = new Contract(this.safeAddress, SAFE_ABI, this.provider);
    this.guardContract = new Contract(this.guardAddress, GUARD_ABI, this.provider);

    this.logger.log(`OnChainExecutor initialized (read-only) for Safe ${this.safeAddress} on chain ${this.chainId}`);
  }

  /**
   * Queries real on-chain parameters directly from the deployed Chapter2Guard contract on Base Sepolia.
   */
  async getOnChainGuardConfig(): Promise<{
    maxAutonomousAmount: bigint;
    dailyAutonomousLimit: bigint;
    remainingDailyBudget: bigint;
    safeAddress: string;
  }> {
    const [maxAutonomousAmount, dailyAutonomousLimit, remainingDailyBudget, safeAddress] =
      await Promise.all([
        this.guardContract.maxAutonomousAmount(),
        this.guardContract.dailyAutonomousLimit(),
        this.guardContract.getRemainingDailyBudget(),
        this.guardContract.safeAddress(),
      ]);

    return {
      maxAutonomousAmount: BigInt(maxAutonomousAmount),
      dailyAutonomousLimit: BigInt(dailyAutonomousLimit),
      remainingDailyBudget: BigInt(remainingDailyBudget),
      safeAddress,
    };
  }

  /**
   * Queries real on-chain parameters directly from the deployed Safe contract on Base Sepolia.
   */
  async getOnChainSafeConfig(): Promise<{
    guardAddress: string;
    nonce: bigint;
    owner: string;
  }> {
    const [guardAddress, nonce, owner] = await Promise.all([
      this.safeContract.getGuard(),
      this.safeContract.nonce(),
      this.safeContract.owner(),
    ]);

    return {
      guardAddress,
      nonce: BigInt(nonce),
      owner,
    };
  }

  /**
   * Reads the humanSigner that the deployed Chapter2Guard accepts for escalated EIP-712 approvals.
   */
  async getGuardHumanSigner(): Promise<string> {
    const guard = new Contract(
      this.guardAddress,
      ['function humanSigner() external view returns (address)'],
      this.provider,
    );
    return getAddress(await guard.humanSigner());
  }

  /**
   * Verifies an on-chain transaction hash receipt against the real Ethereum provider.
   */
  async verifyTransaction(txHash: string): Promise<{
    verified: boolean;
    receipt?: TransactionReceipt;
    error?: string;
  }> {
    if (!txHash || !txHash.startsWith('0x')) {
      return { verified: false, error: 'Invalid transaction hash format' };
    }

    try {
      const receipt = await this.provider.getTransactionReceipt(txHash);
      if (!receipt) {
        return { verified: false, error: 'Transaction receipt not found on-chain' };
      }
      return {
        verified: receipt.status === 1,
        receipt,
      };
    } catch (err) {
      return { verified: false, error: err.message };
    }
  }

  /**
   * Verifies that a mined transaction transferred at least `minimumAmount` of `token` to `recipient`,
   * by decoding ERC-20 Transfer logs from the receipt. Used to redeem x402 payments.
   */
  async verifyTokenTransfer(
    txHash: string,
    expectedTransfer: { token: string; recipient: string; minimumAmount: bigint },
  ): Promise<
    | { verified: true; transferredAmount: bigint }
    | { verified: false; error: string; transferredAmount?: bigint }
  > {
    let receipt: TransactionReceipt | null;
    try {
      receipt = await this.provider.getTransactionReceipt(txHash);
    } catch (err) {
      return { verified: false, error: err.message };
    }

    if (!receipt) {
      return { verified: false, error: 'Transaction receipt not found on-chain' };
    }
    if (receipt.status !== 1) {
      return { verified: false, error: 'Transaction reverted on-chain' };
    }

    const expectedToken = getAddress(expectedTransfer.token);
    const expectedRecipient = getAddress(expectedTransfer.recipient);

    let transferredAmount = 0n;
    for (const log of receipt.logs) {
      if (getAddress(log.address) !== expectedToken) continue;

      let parsedLog;
      try {
        parsedLog = ERC20_TRANSFER_EVENT_INTERFACE.parseLog({
          topics: log.topics as string[],
          data: log.data,
        });
      } catch {
        continue;
      }
      if (!parsedLog || parsedLog.name !== 'Transfer') continue;
      if (getAddress(parsedLog.args.to as string) !== expectedRecipient) continue;

      transferredAmount += BigInt(parsedLog.args.value);
    }

    if (transferredAmount >= expectedTransfer.minimumAmount) {
      return { verified: true, transferredAmount };
    }

    return {
      verified: false,
      error: `Transferred amount ${transferredAmount.toString()} is below required minimum ${expectedTransfer.minimumAmount.toString()}`,
      transferredAmount,
    };
  }

  /**
   * Queries the live on-chain USDC and ETH balances held by the Gnosis Safe treasury vault on Base Sepolia.
   */
  async getTreasuryBalance(): Promise<{ usdcBalance: number; ethBalance: string }> {
    const usdcAddress = process.env.USDC_ADDRESS || '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
    const usdcContract = new Contract(usdcAddress, ERC20_ABI, this.provider);
    const [rawUsdc, rawEth] = await Promise.all([
      usdcContract.balanceOf(this.safeAddress),
      this.provider.getBalance(this.safeAddress),
    ]);
    return {
      usdcBalance: Number(rawUsdc) / 1e6,
      ethBalance: formatEther(rawEth),
    };
  }
}
