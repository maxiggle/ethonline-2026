import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { ActionStoreService } from '../actions/action-store.service';
import { ActionsController } from '../actions/actions.controller';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
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

  // Approved Vendor Recipient from Chapter 2 mandate
  public readonly vendorAddress = '0x0000000000000000000000000000000000041c4e';
  public readonly tokenAddress: string;
  public readonly requiredAmount = '40000000'; // 40 USDC (6 decimals)
  public readonly chainId: number;

  private connectedAccounts: ConnectedAccount[] = [
    {
      id: 'acc_gcp_01',
      provider: 'google_cloud',
      name: 'Google Cloud Platform (GCP)',
      organization: 'Acme Global Enterprises Inc.',
      accountId: 'billingAccounts/01A2B3-456C7D-89EF01',
      status: 'CONNECTED',
      connectedAt: '2026-09-01T08:00:00.000Z',
      projects: ['vertex-ai-models', 'h100-gpu-cluster-prod', 'acme-data-lake'],
    },
    {
      id: 'acc_aws_02',
      provider: 'aws',
      name: 'Amazon Web Services (AWS)',
      organization: 'Acme Global Enterprises Inc.',
      accountId: '129384918231',
      status: 'CONNECTED',
      connectedAt: '2026-08-15T12:30:00.000Z',
      projects: ['guardduty-defense', 'waf-edge-network'],
    },
    {
      id: 'acc_alc_03',
      provider: 'alchemy',
      name: 'Alchemy Supernode Engine',
      organization: 'Acme Global Enterprises Inc.',
      accountId: 'alc_team_acme_2026',
      status: 'CONNECTED',
      connectedAt: '2026-08-20T10:15:00.000Z',
      projects: ['base-sepolia-archive-cluster'],
    },
  ];

  private bills: CompanyBill[] = [];

  constructor(
    private readonly onChainExecutor: OnChainExecutorService,
    private readonly actionStore: ActionStoreService,
    private readonly actionsController: ActionsController,
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

    this.initBills();
  }

  private initBills() {
    this.bills = [
      {
        id: 'bill_gcp_vertex_01',
        provider: 'google_cloud',
        serviceName: 'Google Cloud Vertex AI & H100 Cluster',
        accountId: 'billingAccounts/01A2B3-456C7D-89EF01',
        organization: 'Acme Global Enterprises Inc.',
        invoiceNumber: 'INV-GCP-2026-09-8812',
        amount: '40000000', // 40 USDC
        amountUsdc: 40.0,
        description: 'Autonomous H100 GPU compute cluster allocation & fine-tuning inference',
        paymentIdentifier: 'gcp_01a2b3_inv_8812',
        status: 'UNPAID_402',
        dueDate: '2026-09-18T23:59:59.000Z',
        paymentRequirements: {
          address: this.vendorAddress,
          amount: '40000000',
          token: this.tokenAddress,
          chainId: this.chainId,
        },
      },
      {
        id: 'bill_aws_guardduty_02',
        provider: 'aws',
        serviceName: 'AWS Enterprise Cloud Security & WAF',
        accountId: '129384918231',
        organization: 'Acme Global Enterprises Inc.',
        invoiceNumber: 'INV-AWS-2026-09-1049',
        amount: '850000000', // 850 USDC (exceeds $500 daily limit, triggers Face ID escalation!)
        amountUsdc: 850.0,
        description: 'Dedicated Cloud Security Cluster & Threat Intelligence Annual Renewal',
        paymentIdentifier: 'aws_129384_inv_1049',
        status: 'UNPAID_402',
        dueDate: '2026-09-20T23:59:59.000Z',
        paymentRequirements: {
          address: this.vendorAddress,
          amount: '850000000',
          token: this.tokenAddress,
          chainId: this.chainId,
        },
      },
      {
        id: 'bill_alc_rpc_03',
        provider: 'alchemy',
        serviceName: 'Alchemy Dedicated RPC Node Infrastructure',
        accountId: 'alc_team_acme_2026',
        organization: 'Acme Global Enterprises Inc.',
        invoiceNumber: 'INV-ALC-2026-09-0211',
        amount: '25000000', // 25 USDC
        amountUsdc: 25.0,
        description: 'Base Sepolia High-Throughput Archive Node Bandwidth',
        paymentIdentifier: 'alc_team_inv_0211',
        status: 'UNPAID_402',
        dueDate: '2026-09-22T23:59:59.000Z',
        paymentRequirements: {
          address: this.vendorAddress,
          amount: '25000000',
          token: this.tokenAddress,
          chainId: this.chainId,
        },
      },
    ];
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

  markBillSettled(billId: string, txHash: string): CompanyBill {
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

  // --- Legacy Compute Requirements ---
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

    // If matches any bill, mark it settled
    const gcpBill = this.bills.find((b) => b.id === 'bill_gcp_vertex_01');
    if (gcpBill && gcpBill.status === 'UNPAID_402') {
      this.markBillSettled(gcpBill.id, txHash);
    }

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

  // --- Bazaar Discovery Catalog ---
  getBazaarCatalog(): BazaarResource[] {
    const baseUrl = process.env.RENDER_EXTERNAL_URL || 'https://chapter2-backend.onrender.com';

    return [
      {
        resource: `${baseUrl}/vendor/bills/bill_gcp_vertex_01`,
        type: 'http',
        x402Version: 2,
        lastUpdated: new Date().toISOString(),
        accepts: [
          {
            network: `eip155:${this.chainId}`,
            asset: this.tokenAddress,
            amount: '40000000',
            payTo: this.vendorAddress,
            scheme: 'exact',
            extra: {
              name: 'USD Coin',
              version: '2',
              paymentIdentifier: 'gcp_01a2b3_inv_8812',
            },
          },
        ],
        extensions: {
          bazaar: {
            info: {
              serviceName: 'Google Cloud Vertex AI & H100 Cluster',
              description: 'Autonomous H100 GPU compute cluster allocation & fine-tuning inference',
              tags: ['gpu', 'ai', 'compute', 'google-cloud', 'h100'],
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
                  sessionToken: 'sess_17892289_9a8f21',
                  specs: '1x NVIDIA H100 Tensor Core GPU (80GB SXM5)',
                },
              },
            },
          },
        },
      },
      {
        resource: `${baseUrl}/vendor/bills/bill_aws_guardduty_02`,
        type: 'http',
        x402Version: 2,
        lastUpdated: new Date().toISOString(),
        accepts: [
          {
            network: `eip155:${this.chainId}`,
            asset: this.tokenAddress,
            amount: '850000000',
            payTo: this.vendorAddress,
            scheme: 'exact',
            extra: {
              name: 'USD Coin',
              version: '2',
              paymentIdentifier: 'aws_129384_inv_1049',
            },
          },
        ],
        extensions: {
          bazaar: {
            info: {
              serviceName: 'AWS Enterprise Cloud Security & WAF',
              description: 'Dedicated Cloud Security Cluster & Threat Intelligence Annual Subscription',
              tags: ['security', 'aws', 'waf', 'guardduty', 'threat-defense'],
              input: {
                type: 'http',
                method: 'GET',
              },
              output: {
                type: 'json',
                example: {
                  status: 'UNLOCKED',
                  licenseKey: 'aws-ent-sec-2026-904',
                  activeRules: 24,
                },
              },
            },
          },
        },
      },
      {
        resource: `${baseUrl}/vendor/bills/bill_alc_rpc_03`,
        type: 'http',
        x402Version: 2,
        lastUpdated: new Date().toISOString(),
        accepts: [
          {
            network: `eip155:${this.chainId}`,
            asset: this.tokenAddress,
            amount: '25000000',
            payTo: this.vendorAddress,
            scheme: 'exact',
            extra: {
              name: 'USD Coin',
              version: '2',
              paymentIdentifier: 'alc_team_inv_0211',
            },
          },
        ],
        extensions: {
          bazaar: {
            info: {
              serviceName: 'Alchemy Dedicated RPC Node Infrastructure',
              description: 'Base Sepolia High-Throughput Archive Node Bandwidth',
              tags: ['rpc', 'alchemy', 'node', 'archive', 'ethereum'],
              input: {
                type: 'http',
                method: 'GET',
              },
              output: {
                type: 'json',
                example: {
                  status: 'UNLOCKED',
                  endpoint: 'https://base-sepolia.g.alchemy.com/v2/private-dedicated',
                  dailyComputeUnits: 50000000,
                },
              },
            },
          },
        },
      },
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

  async invokeService(
    resourceUrl: string,
    method = 'GET',
    params?: Record<string, any>,
    agentAddress?: string,
  ): Promise<{
    status: 'SUCCESS' | 'ESCALATED';
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
    const cleanUrl = (resourceUrl || '').trim().toLowerCase();
    const service =
      catalog.find(
        (s) =>
          s.resource.toLowerCase() === cleanUrl ||
          cleanUrl.includes(s.resource.toLowerCase()) ||
          s.resource.toLowerCase().endsWith(cleanUrl.replace(/^https?:\/\/[^/]+/, '')),
      ) || catalog[0];

    const serviceName = service.extensions.bazaar.info.serviceName;
    const accept = service.accepts[0];
    const amountUnits = accept.amount;
    const costUsdc = Number(amountUnits) / 1e6;
    const effectiveAgent = agentAddress || '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';

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

    if (
      proposalResult.decision?.decision === 'ESCALATE' ||
      proposalResult.decision?.requiresHumanApproval
    ) {
      return {
        status: 'ESCALATED',
        serviceName,
        resourceUrl: service.resource,
        costUsdc,
        decision: 'ESCALATE',
        reason: `Service cost of $${costUsdc.toFixed(2)} USDC exceeds autonomous spending limit ($500). Biometric approval required.`,
        action: proposalResult.action,
        executionTimestamp: new Date().toISOString(),
      };
    }

    const txHash = proposalResult.action?.txHash;
    const finalParams = params || service.extensions.bazaar.info.input.queryParams || {};
    let responseData: Record<string, any>;

    if (service.resource.includes('/vendor/weather')) {
      const city = (finalParams.city as string) || 'San Francisco';
      responseData = this.getWeatherTelemetry(city, txHash);
    } else if (service.resource.includes('/vendor/bills/bill_gcp_vertex_01')) {
      responseData = await this.verifyAndGrantAccess(txHash);
    } else {
      responseData = {
        status: 'UNLOCKED',
        service: serviceName,
        endpoint: service.resource,
        settlementTx: txHash,
        params: finalParams,
        result: service.extensions.bazaar.info.output.example,
        timestamp: new Date().toISOString(),
      };
    }

    return {
      status: 'SUCCESS',
      serviceName,
      resourceUrl: service.resource,
      txHash,
      costUsdc,
      decision: proposalResult.decision?.decision || 'ALLOW',
      data: responseData,
      executionTimestamp: new Date().toISOString(),
    };
  }

  getWeatherTelemetry(city: string, txHash?: string): Record<string, any> {
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
      settlementTx: txHash || '0x_settlement_unverified',
      paidVia: 'Chapter 2 Guardian x402 Safe Multisig',
      timestamp: new Date().toISOString(),
    };
  }
}
