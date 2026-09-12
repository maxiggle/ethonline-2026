import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { ActionsController } from '../actions/actions.controller';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { DatabaseService } from '../database/database.service';
import { X402PaymentReceiptRow } from '../database/database.interface';

const TX_HASH_PATTERN = /^0x[0-9a-fA-F]{64}$/;

export interface PaymentRequirements {
  address: string;
  amount: string;
  token: string;
  chainId: number;
  paymentIdentifier?: string;
}

export type InvokeServiceStatus = 'SUCCESS' | 'ESCALATED' | 'BLOCKED' | 'PENDING_SETTLEMENT';

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

export interface ConnectedAccount {
  id: string;
  provider: 'google_cloud' | 'aws' | 'alchemy' | 'openai';
  name: string;
  organization: string;
  accountId: string;
  status: 'CONNECTED' | 'DISCONNECTED';
  connectedAt: string;
  projects?: string[];
}

export interface CompanyBill {
  id: string;
  provider: 'google_cloud' | 'aws' | 'alchemy' | 'openai';
  serviceName: string;
  accountId: string;
  organization: string;
  invoiceNumber: string;
  amount: string; // atomic units (6 decimals for USDC)
  amountUsdc: number;
  description: string;
  paymentIdentifier: string;
  status: 'UNPAID_402' | 'SETTLED_200';
  paymentRequirements: PaymentRequirements;
  txHash?: string;
  unlockedGrant?: ComputeResourceGrant;
  dueDate: string;
}

export interface BazaarResource {
  resource: string;
  type: 'http' | 'mcp';
  x402Version: number;
  lastUpdated: string;
  accepts: Array<{
    network: string;
    asset: string;
    amount: string;
    payTo: string;
    scheme: string;
    extra?: Record<string, any>;
  }>;
  extensions: {
    bazaar: {
      info: {
        serviceName: string;
        description: string;
        tags: string[];
        input: {
          type: string;
          method: string;
          queryParams?: Record<string, any>;
          bodyParams?: Record<string, any>;
        };
        output: {
          type: string;
          example: Record<string, any>;
        };
      };
    };
  };
}

@Injectable()
export class VendorService {
  private readonly logger = new Logger(VendorService.name);

  public readonly tokenAddress: string;
  public readonly chainId: number;

  public get vendorAddress(): string {
    return (
      process.env.VENDOR_RECIPIENT_ADDRESS ||
      process.env.SAFE_ADDRESS ||
      '0x0000000000000000000000000000000000000000'
    );
  }

  public get requiredAmount(): string {
    return '40000000'; // 40 USDC (6 decimals)
  }

  private connectedAccounts: ConnectedAccount[] = [];
  private bills: CompanyBill[] = [];

  constructor(
    private readonly onChainExecutor: OnChainExecutorService,
    private readonly actionsController: ActionsController,
    private readonly databaseService: DatabaseService,
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

  // --- Accounts API ---
  getConnectedAccounts(): ConnectedAccount[] {
    return this.connectedAccounts;
  }

  connectAccount(dto: {
    provider: 'google_cloud' | 'aws' | 'alchemy' | 'openai';
    name: string;
    organization: string;
    accountId: string;
    projects?: string[];
  }): ConnectedAccount {
    const existing = this.connectedAccounts.find((a) => a.accountId === dto.accountId);
    if (existing) {
      existing.status = 'CONNECTED';
      existing.connectedAt = new Date().toISOString();
      if (dto.projects) existing.projects = dto.projects;
      return existing;
    }

    const newAcc: ConnectedAccount = {
      id: `acc_${dto.provider}_${Date.now()}`,
      provider: dto.provider,
      name: dto.name,
      organization: dto.organization || 'Acme Global Enterprises Inc.',
      accountId: dto.accountId,
      status: 'CONNECTED',
      connectedAt: new Date().toISOString(),
      projects: dto.projects || ['default-project'],
    };

    this.connectedAccounts.push(newAcc);
    return newAcc;
  }

  disconnectAccount(accountId: string): boolean {
    const acc = this.connectedAccounts.find((a) => a.accountId === accountId);
    if (!acc) return false;
    acc.status = 'DISCONNECTED';
    return true;
  }

  // --- Bills API ---
  getBills(): CompanyBill[] {
    return this.bills;
  }

  getBillById(id: string): CompanyBill | undefined {
    return this.bills.find((b) => b.id === id);
  }

  private markBillSettled(billId: string, txHash: string): CompanyBill {
    const bill = this.getBillById(billId);
    if (!bill) {
      throw new NotFoundException(`Company bill ${billId} not found`);
    }

    bill.status = 'SETTLED_200';
    bill.txHash = txHash;
    const now = Date.now();
    bill.unlockedGrant = {
      status: 'UNLOCKED',
      resource: `${bill.provider}:${bill.invoiceNumber}`,
      txHash,
      sessionToken: `sess_${now}_${txHash.substring(2, 10)}`,
      message: `Invoice ${bill.invoiceNumber} verified on Base Sepolia. Corporate services active.`,
      expiresAt: new Date(now + 30 * 86400 * 1000).toISOString(),
      details: {
        specs: bill.description,
        cluster: `acme-${bill.provider}-dedicated-pool`,
        allocatedVramGb: 80,
      },
    };

    this.logger.log(
      `Company bill ${billId} (${bill.invoiceNumber}) settled on-chain with tx ${txHash}`,
    );

    return bill;
  }

  addBill(bill: CompanyBill): CompanyBill {
    this.bills.push(bill);
    return bill;
  }

  // --- Legacy Compute Requirements ---
  getPaymentRequirements(): PaymentRequirements {
    return {
      address: this.vendorAddress,
      amount: this.requiredAmount,
      token: this.tokenAddress,
      chainId: this.chainId,
    };
  }

  /**
   * Redeems an on-chain payment for a specific resource: rejects malformed hashes, wrong-chain
   * requirements and replays (a hash already present in x402_payment_receipts), then verifies the
   * ERC-20 transfer on-chain before recording the receipt. Each hash can be redeemed once, ever,
   * across all resources.
   */
  async redeemPayment(
    txHash: string,
    requirements: PaymentRequirements,
    resourceId: string,
  ): Promise<string> {
    if (!txHash || !TX_HASH_PATTERN.test(txHash)) {
      throw new BadRequestException(`Malformed X-Payment-TxHash: '${txHash}'`);
    }
    if (requirements.chainId !== this.chainId) {
      throw new BadRequestException(
        `Payment requirements chainId ${requirements.chainId} does not match configured chain ${this.chainId}`,
      );
    }

    const lowerHash = txHash.toLowerCase();
    const existingReceipt = await this.databaseService.getOne<X402PaymentReceiptRow>(
      'SELECT * FROM x402_payment_receipts WHERE tx_hash = ?',
      [lowerHash],
    );
    if (existingReceipt) {
      throw new BadRequestException(
        `Payment ${lowerHash} was already redeemed for ${existingReceipt.resource}`,
      );
    }

    const verifyResult = await this.onChainExecutor.verifyTokenTransfer(txHash, {
      token: requirements.token,
      recipient: requirements.address,
      minimumAmount: BigInt(requirements.amount),
    });
    if (verifyResult.verified === false) {
      throw new BadRequestException(`On-chain payment verification failed: ${verifyResult.error}`);
    }

    const insertResult = await this.databaseService.run(
      'INSERT INTO x402_payment_receipts (tx_hash, resource, amount, redeemed_at) VALUES (?, ?, ?, ?) ON CONFLICT (tx_hash) DO NOTHING',
      [lowerHash, resourceId, requirements.amount, new Date().toISOString()],
    );
    if (insertResult.changes === 0) {
      throw new BadRequestException(`Payment ${lowerHash} was already redeemed (concurrent replay)`);
    }

    return lowerHash;
  }

  async verifyAndGrantAccess(txHash: string): Promise<ComputeResourceGrant> {
    const redeemedHash = await this.redeemPayment(txHash, this.getPaymentRequirements(), 'vendor:compute');

    this.logger.log(`x402 Payment verified for tx ${redeemedHash}. Unlocking compute session.`);

    const now = Date.now();
    return {
      status: 'UNLOCKED',
      resource: 'compute:dedicated-cluster:h100-gpu-node-01',
      txHash: redeemedHash,
      sessionToken: `sess_${now}_${redeemedHash.substring(2, 10)}`,
      message: 'x402 payment successfully settled on-chain. Compute resource unlocked.',
      expiresAt: new Date(now + 3600 * 1000).toISOString(),
      details: {
        specs: '1x NVIDIA H100 Tensor Core GPU (80GB SXM5)',
        cluster: 'base-sepolia-autonomous-compute-pool-01',
        allocatedVramGb: 80,
      },
    };
  }

  /**
   * Settles a specific company bill with an on-chain payment. Idempotent for the same hash;
   * rejects a second, different hash once the bill is already settled.
   */
  async settleBillWithPayment(billId: string, txHash: string): Promise<CompanyBill> {
    const bill = this.getBillById(billId);
    if (!bill) {
      throw new NotFoundException(`Company bill ${billId} not found`);
    }

    if (bill.status === 'SETTLED_200' && bill.txHash) {
      if (bill.txHash.toLowerCase() === (txHash || '').toLowerCase()) {
        return bill;
      }
      throw new BadRequestException(
        `Company bill ${billId} is already settled with a different payment (${bill.txHash})`,
      );
    }

    const redeemedHash = await this.redeemPayment(txHash, bill.paymentRequirements, `bill:${billId}`);
    return this.markBillSettled(billId, redeemedHash);
  }

  // --- Bazaar Discovery Catalog ---
  getBazaarCatalog(): BazaarResource[] {
    const baseUrl = process.env.RENDER_EXTERNAL_URL || 'https://chapter2-backend.onrender.com';

    return [
      {
        resource: `${baseUrl}/vendor/weather`,
        type: 'http',
        x402Version: 2,
        lastUpdated: new Date().toISOString(),
        accepts: [
          {
            network: `eip155:${this.chainId}`,
            asset: this.tokenAddress,
            amount: '1000000', // 1.00 USDC
            payTo: this.vendorAddress,
            scheme: 'exact',
            extra: {
              name: 'USD Coin',
              version: '2',
              paymentIdentifier: 'weather_oracle_inv_004',
            },
          },
        ],
        extensions: {
          bazaar: {
            info: {
              serviceName: 'AccuWeather & Climate Intelligence Oracle',
              description:
                'Hyper-local real-time weather telemetry, radar forecasting, and climate oracle feed',
              tags: ['weather', 'climate', 'api', 'forecasting', 'radar', 'oracle', 'environment'],
              input: {
                type: 'http',
                method: 'GET',
                queryParams: {
                  city: 'San Francisco',
                  units: 'metric',
                },
              },
              output: {
                type: 'json',
                example: {
                  city: 'San Francisco',
                  temperatureC: 18.5,
                  conditions: 'Partly Cloudy',
                  humidity: 68,
                  windSpeedKph: 14.2,
                },
              },
            },
          },
        },
      },
      {
        resource: `${baseUrl}/vendor/compute`,
        type: 'http',
        x402Version: 2,
        lastUpdated: new Date().toISOString(),
        accepts: [
          {
            network: `eip155:${this.chainId}`,
            asset: this.tokenAddress,
            amount: '40000000', // 40.00 USDC
            payTo: this.vendorAddress,
            scheme: 'exact',
            extra: {
              name: 'USD Coin',
              version: '2',
              paymentIdentifier: 'compute_cluster_session_01',
            },
          },
        ],
        extensions: {
          bazaar: {
            info: {
              serviceName: 'Decentralized GPU Compute & AI Inference',
              description:
                'Autonomous H100 GPU compute cluster allocation, model inference, and fine-tuning',
              tags: ['compute', 'gpu', 'ai', 'inference', 'h100', 'cluster', 'nvidia'],
              input: {
                type: 'http',
                method: 'GET',
                queryParams: {
                  clusterId: 'vertex-h100-node-01',
                },
              },
              output: {
                type: 'json',
                example: {
                  status: 'UNLOCKED',
                  sessionToken: 'sess_live_cluster_alloc',
                  specs: '1x NVIDIA H100 Tensor Core GPU (80GB SXM5)',
                  allocatedVramGb: 80,
                },
              },
            },
          },
        },
      },
    ];
  }

  searchBazaar(query?: string, type?: string): BazaarResource[] {
    let items = this.getBazaarCatalog();
    if (type) {
      items = items.filter((i) => i.type.toLowerCase() === type.toLowerCase());
    }
    if (query && query.trim().length > 0) {
      const q = query.trim().toLowerCase();
      const tokens = q.split(/\s+/).filter((t) => t.length > 0);
      items = items.filter((i) => {
        const name = i.extensions.bazaar.info.serviceName.toLowerCase();
        const desc = i.extensions.bazaar.info.description.toLowerCase();
        const tags = i.extensions.bazaar.info.tags.map((t) => t.toLowerCase());

        // Exact match
        if (name.includes(q) || desc.includes(q) || tags.some((t) => t.includes(q))) {
          return true;
        }

        // Token match
        return tokens.some(
          (tok) =>
            name.includes(tok) ||
            desc.includes(tok) ||
            tags.some((t) => t.includes(tok)),
        );
      });
    }
    return items;
  }

  private resourcePathOf(url: string): string {
    return (url || '')
      .trim()
      .replace(/^https?:\/\/[^/]+/i, '')
      .split('?')[0]
      .replace(/\/+$/, '')
      .toLowerCase();
  }

  async invokeService(
    resourceUrl: string,
    method = 'GET',
    params?: Record<string, any>,
    agentAddress?: string,
  ): Promise<{
    status: InvokeServiceStatus;
    serviceName: string;
    resourceUrl: string;
    txHash?: string;
    costUsdc: number;
    decision: string;
    data?: Record<string, any>;
    reason?: string;
    action?: any;
    executionTimestamp: string;
  }> {
    const catalog = this.getBazaarCatalog();
    const requestedPath = this.resourcePathOf(resourceUrl);
    const service = catalog.find((s) => this.resourcePathOf(s.resource) === requestedPath);
    if (!service) {
      throw new NotFoundException(`Unknown x402 resource: '${resourceUrl}'`);
    }

    const serviceName = service.extensions.bazaar.info.serviceName;
    const accept = service.accepts[0];
    const amountUnits = accept.amount;
    const costUsdc = Number(amountUnits) / 1e6;
    const effectiveAgent = agentAddress || '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
    const isWeather = service.resource.includes('/vendor/weather');
    const isCompute = service.resource.includes('/vendor/compute');
    const finalParams = params || service.extensions.bazaar.info.input.queryParams || {};

    if (isWeather && !finalParams.city) {
      throw new BadRequestException("Weather service requires a 'city' parameter");
    }

    this.logger.log(
      `Invoking Bazaar service "${serviceName}" at ${service.resource} (Cost: $${costUsdc} USDC, Agent: ${effectiveAgent})`,
    );

    const proposePayload: ProposeActionDto = {
      target: accept.asset,
      value: '0',
      data: '0xa9059cbb',
      token: accept.asset,
      recipient: accept.payTo,
      amount: amountUnits,
      agentAddress: effectiveAgent,
      justification: `x402 Bazaar Invocation: ${serviceName} [${service.resource}]`,
    };

    const proposalResult = await this.actionsController.proposeAction(proposePayload);
    const decisionType = proposalResult.decision?.decision;
    const reason = (proposalResult.decision?.reasons || []).join('; ') || undefined;

    if (decisionType === GuardianDecisionType.BLOCK) {
      return {
        status: 'BLOCKED',
        serviceName,
        resourceUrl: service.resource,
        costUsdc,
        decision: decisionType,
        reason,
        action: proposalResult.action,
        executionTimestamp: new Date().toISOString(),
      };
    }

    if (decisionType === GuardianDecisionType.ESCALATE || proposalResult.decision?.requiresHumanApproval) {
      return {
        status: 'ESCALATED',
        serviceName,
        resourceUrl: service.resource,
        costUsdc,
        decision: decisionType || GuardianDecisionType.ESCALATE,
        reason,
        action: proposalResult.action,
        executionTimestamp: new Date().toISOString(),
      };
    }

    const txHash = proposalResult.action?.txHash;
    if (!txHash) {
      return {
        status: 'PENDING_SETTLEMENT',
        serviceName,
        resourceUrl: service.resource,
        costUsdc,
        decision: decisionType || GuardianDecisionType.ALLOW,
        action: proposalResult.action,
        executionTimestamp: new Date().toISOString(),
      };
    }

    let responseData: Record<string, any>;
    if (isWeather) {
      responseData = await this.getPaidWeatherTelemetry(finalParams.city as string, txHash);
    } else if (isCompute) {
      responseData = await this.verifyAndGrantAccess(txHash);
    } else {
      throw new NotFoundException(`No settlement handler for resource: ${service.resource}`);
    }

    return {
      status: 'SUCCESS',
      serviceName,
      resourceUrl: service.resource,
      txHash,
      costUsdc,
      decision: decisionType || GuardianDecisionType.ALLOW,
      data: responseData,
      executionTimestamp: new Date().toISOString(),
    };
  }

  getWeatherPaymentRequirements(): PaymentRequirements {
    return {
      address: this.vendorAddress,
      amount: '1000000', // 1.00 USDC
      token: this.tokenAddress,
      chainId: this.chainId,
      paymentIdentifier: 'weather_oracle_inv_004',
    };
  }

  async getPaidWeatherTelemetry(city: string, txHash: string): Promise<Record<string, any>> {
    const redeemedHash = await this.redeemPayment(
      txHash,
      this.getWeatherPaymentRequirements(),
      'vendor:weather',
    );
    return this.buildWeatherTelemetry(city, redeemedHash);
  }

  private buildWeatherTelemetry(city: string, txHash: string): Record<string, any> {
    const isSF = city.toLowerCase().includes('san francisco');
    return {
      city: isSF ? 'San Francisco, CA' : city,
      temperatureC: isSF ? 18.5 : 22.0,
      temperatureF: isSF ? 65.3 : 71.6,
      conditions: isSF ? 'Partly Cloudy / Bay Marine Layer' : 'Clear Skies',
      humidity: isSF ? 68 : 55,
      windSpeedKph: isSF ? 14.2 : 9.5,
      pressureHpa: 1014,
      uvIndex: 4,
      forecast: [
        { day: 'Today', highC: 19, lowC: 12, condition: 'Partly Cloudy' },
        { day: 'Tomorrow', highC: 20, lowC: 13, condition: 'Sunny' },
        { day: 'Day 3', highC: 22, lowC: 14, condition: 'Clear' },
      ],
      oracleFeed: 'AccuWeather Enterprise Node (Base Sepolia)',
      settlementTx: txHash,
      paidVia: 'Chapter 2 Guardian x402 Safe Multisig',
      timestamp: new Date().toISOString(),
    };
  }
}
