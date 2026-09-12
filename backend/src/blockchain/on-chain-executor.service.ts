import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import {
  JsonRpcProvider,
  Wallet,
  Contract,
  Interface,
  ZeroAddress,
  getAddress,
  TransactionReceipt,
  formatEther,
} from 'ethers';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';
import { ActionStoreService } from '../actions/action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { Eip712Service } from '../crypto/eip712.service';
import { EventsGateway } from '../gateway/events.gateway';
import { TreasuryActionApprovalParams } from '../crypto/interfaces/eip712.interface';

const SAFE_ABI = [
  'function execTransaction(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address payable refundReceiver, bytes memory signatures) external payable returns (bool success)',
  'function getGuard() external view returns (address)',
  'function nonce() external view returns (uint256)',
  'function owner() external view returns (address)',
  'event ExecutionSuccess(bytes32 txHash, uint256 payment)',
  'event ExecutionFailure(bytes32 txHash, uint256 payment)',
];

const GUARD_ABI = [
  'function maxAutonomousAmount() external view returns (uint256)',
  'function dailyAutonomousLimit() external view returns (uint256)',
  'function getRemainingDailyBudget() external view returns (uint256)',
  'function safeAddress() external view returns (address)',
  'function autonomousAgent() external view returns (address)',
  'function isApprovedRecipient(address recipient) external view returns (bool)',
  'function isApprovedToken(address token) external view returns (bool)',
  'function setAutonomousAgent(address _agent) external',
];

const ERC20_ABI = [
  'function transfer(address to, uint256 amount) external returns (bool)',
  'function balanceOf(address account) external view returns (uint256)',
];

@Injectable()
export class OnChainExecutorService {
  private readonly logger = new Logger(OnChainExecutorService.name);
  public readonly provider: JsonRpcProvider;
  public readonly relayerWallet: Wallet;
  public readonly safeContract: Contract;
  public readonly guardContract: Contract;

  public readonly rpcUrl: string;
  public readonly safeAddress: string;
  public readonly guardAddress: string;
  public readonly chainId: number;

  constructor(
    private readonly actionStore: ActionStoreService,
    private readonly policyEngine: PolicyEngineService,
    private readonly eip712Service: Eip712Service,
    private readonly eventsGateway: EventsGateway,
  ) {
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

    const relayerKey = process.env.RELAYER_PRIVATE_KEY;
    if (!relayerKey) {
      throw new Error(
        'Missing required environment variable: RELAYER_PRIVATE_KEY. Execution cannot proceed without a configured signer.',
      );
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
    this.relayerWallet = new Wallet(relayerKey, this.provider);
    this.safeContract = new Contract(this.safeAddress, SAFE_ABI, this.relayerWallet);
    this.guardContract = new Contract(this.guardAddress, GUARD_ABI, this.provider);

    this.logger.log(
      `OnChainExecutor initialized for Safe ${this.safeAddress} on chain ${this.chainId} (Relayer: ${this.relayerWallet.address})`,
    );
  }

  private txMutex: Promise<any> = Promise.resolve();

  private async runWithMutex<T>(fn: () => Promise<T>): Promise<T> {
    const prev = this.txMutex;
    let resolveNext: () => void;
    this.txMutex = new Promise<void>((resolve) => {
      resolveNext = resolve;
    });

    try {
      await prev.catch(() => {});
      return await fn();
    } finally {
      resolveNext!();
    }
  }

  private encodeErc20Transfer(recipient: string, amount: string): string {
    const iface = new Interface(ERC20_ABI);
    return iface.encodeFunctionData('transfer', [getAddress(recipient), BigInt(amount)]);
  }

  /**
   * Broadcasts real autonomous Safe transfer to Base Sepolia
   * Enforced under Chapter2Guard.checkTransaction() rules.
   */
  async executeAutonomousPayment(action: TreasuryAction): Promise<{
    txHash: string;
    receipt: TransactionReceipt;
    status: TreasuryActionStatus;
  }> {
    return this.runWithMutex(async () => {
      const mandate = this.policyEngine.getMandate();

      if (BigInt(action.amount) > mandate.maxAutonomousAmount) {
        throw new BadRequestException(
          `Amount ${action.amount} exceeds autonomous threshold of ${mandate.maxAutonomousAmount.toString()}`,
        );
      }

      const isErc20 =
        action.token &&
        action.token !== ZeroAddress &&
        action.token.toLowerCase() !== this.safeAddress.toLowerCase();

      const targetAddress = isErc20 ? action.token : action.recipient;
      const callData = isErc20
        ? (action.data && action.data !== '0x' && action.data.length >= 68
            ? action.data
            : this.encodeErc20Transfer(action.recipient, action.amount))
        : (action.data && action.data !== '0x' ? action.data : '0x');
      const callValue = isErc20 ? 0 : (action.value || 0);

      try {
        const tx = await this.safeContract.execTransaction(
          targetAddress,
          callValue,
          callData,
          0, // Operation.Call
          0,
          0,
          0,
          ZeroAddress,
          ZeroAddress,
          '0x',
        );

        const receipt: TransactionReceipt = await tx.wait();
        if (!receipt || receipt.status !== 1) {
          throw new Error(`Transaction reverted on-chain: ${receipt?.hash || tx.hash}`);
        }

        const txHash = receipt.hash;
        action.status = TreasuryActionStatus.EXECUTED;
        action.txHash = txHash;
        action.updatedAt = new Date();

        this.actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash });
        this.eventsGateway.emitActionExecuted({ action, txHash });

        this.logger.log(`Autonomous action ${action.id} executed on-chain: txHash ${txHash}`);
        return { txHash, receipt, status: TreasuryActionStatus.EXECUTED };
      } catch (err) {
        this.logger.error(`On-chain autonomous execution failed: ${err.message}`);
        throw new BadRequestException(`On-chain execution failed: ${err.message}`);
      }
    });
  }

  /**
   * Broadcasts real escalated Safe transfer with human EIP-712 clear-signed payload.
   * Chapter2Guard validates hardware signature, consumes nonce, and executes transfer.
   */
  async executeEscalatedPayment(
    action: TreasuryAction,
    signatureHex: string,
  ): Promise<{
    txHash: string;
    receipt: TransactionReceipt;
    status: TreasuryActionStatus;
  }> {
    return this.runWithMutex(async () => {
      const mandate = this.policyEngine.getMandate();
      const mandateHash = this.eip712Service.computeDomainSeparator({
        name: 'Chapter2',
        version: '1',
        chainId: BigInt(this.chainId),
        verifyingContract: this.guardAddress,
      });

      const approvalParams: TreasuryActionApprovalParams = {
        actionId: action.id,
        agent: action.agentAddress,
        recipient: action.recipient,
        token: action.token,
        amount: action.amount,
        nonce: action.nonce,
        deadline: action.deadline,
        mandateHash,
        riskScore: action.riskScore,
      };

      const encodedPayload = this.eip712Service.encodeEscalatedPayload(
        approvalParams,
        signatureHex,
      );

      const isErc20 =
        action.token &&
        action.token !== ZeroAddress &&
        action.token.toLowerCase() !== this.safeAddress.toLowerCase();

      const targetAddress = isErc20 ? action.token : action.recipient;
      const callData = isErc20
        ? (action.data && action.data !== '0x' && action.data.length >= 68
            ? action.data
            : this.encodeErc20Transfer(action.recipient, action.amount))
        : (action.data && action.data !== '0x' ? action.data : '0x');
      const callValue = isErc20 ? 0 : (action.value || 0);

      try {
        const tx = await this.safeContract.execTransaction(
          targetAddress,
          callValue,
          callData,
          0,
          0,
          0,
          0,
          ZeroAddress,
          ZeroAddress,
          encodedPayload,
        );

        const receipt: TransactionReceipt = await tx.wait();
        if (!receipt || receipt.status !== 1) {
          throw new Error(`Escalated transaction reverted on-chain: ${receipt?.hash || tx.hash}`);
        }

        const txHash = receipt.hash;
        action.status = TreasuryActionStatus.EXECUTED;
        action.txHash = txHash;
        action.signature = signatureHex;
        action.updatedAt = new Date();

        this.actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, {
          txHash,
          signature: signatureHex,
        });
        this.eventsGateway.emitActionExecuted({ action, txHash });

        this.logger.log(`Escalated action ${action.id} executed on-chain: txHash ${txHash}`);
        return { txHash, receipt, status: TreasuryActionStatus.EXECUTED };
      } catch (err) {
        this.logger.error(`On-chain escalated execution failed: ${err.message}`);
        throw new BadRequestException(`On-chain escalated execution failed: ${err.message}`);
      }
    });
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
   * Updates the authorized autonomousAgent on the deployed Chapter2Guard contract on Base Sepolia.
   * Executed by the contract owner (relayerWallet).
   */
  async setAutonomousAgent(agentAddress: string): Promise<string> {
    const checksummed = getAddress(agentAddress);
    return this.runWithMutex(async () => {
      this.logger.log(`Registering autonomous agent ${checksummed} on Guard ${this.guardAddress}...`);
      const guardWithSigner = new Contract(this.guardAddress, GUARD_ABI, this.relayerWallet);
      const tx = await guardWithSigner.setAutonomousAgent(checksummed);
      this.logger.log(`Broadcasted setAutonomousAgent tx ${tx.hash}, waiting for confirmation...`);
      const receipt: TransactionReceipt = await tx.wait();
      if (!receipt || receipt.status !== 1) {
        throw new Error(`setAutonomousAgent transaction failed or reverted: ${receipt?.hash || tx.hash}`);
      }
      this.logger.log(`Autonomous agent successfully updated on-chain to ${checksummed} (Tx: ${receipt.hash})`);
      return receipt.hash;
    });
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
