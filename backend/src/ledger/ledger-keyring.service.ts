import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { Wallet, getAddress } from 'ethers';
import * as crypto from 'crypto';
import { spawn } from 'child_process';
import { Eip712Service } from '../crypto/eip712.service';
import {
  Eip712Domain,
  TreasuryActionApprovalParams,
} from '../crypto/interfaces/eip712.interface';
import {
  DEFAULT_BASE_SEPOLIA_DOMAIN,
  EIP712_ACTION_APPROVAL_TYPES,
} from '../crypto/eip712.constants';
import {
  LedgerDeviceStatus,
  LedgerMode,
  LedgerClearSignPrompt,
  LedgerClearSignField,
  KeyRingSignResult,
  KeyRingSecret,
} from './interfaces/ledger-keyring.interface';
import {
  DEFAULT_DERIVATION_PATH,
  DEFAULT_MOCK_LEDGER_KEY,
  DEFAULT_LEDGER_MODEL,
  DEFAULT_WALLET_CLI_COMMAND,
  CLEAR_SIGN_TITLE,
} from './ledger.constants';

@Injectable()
export class LedgerKeyRingService {
  private readonly logger = new Logger(LedgerKeyRingService.name);
  private mode: LedgerMode;
  private signerWallet: Wallet;
  private derivationPath: string;
  private cliBinaryPath: string;
  private readonly secretVault = new Map<string, KeyRingSecret>();
  private masterRingKey: Buffer;

  constructor(private readonly eip712Service: Eip712Service) {
    this.mode = (process.env.LEDGER_MODE as LedgerMode) || 'MOCK_HARDWARE';
    this.derivationPath = process.env.LEDGER_DERIVATION_PATH || DEFAULT_DERIVATION_PATH;
    this.cliBinaryPath = process.env.LEDGER_CLI_PATH || DEFAULT_WALLET_CLI_COMMAND;

    const privateKey = process.env.LEDGER_SIGNER_PRIVATE_KEY || DEFAULT_MOCK_LEDGER_KEY;
    this.signerWallet = new Wallet(privateKey);

    // Derive 32-byte key for AES-256-GCM headless LKRP operations
    const ringPassphrase = process.env.WALLET_PASS || 'chapter2_secure_ledger_ring_master';
    this.masterRingKey = crypto.scryptSync(ringPassphrase, 'ledger_keyring_salt', 32);
  }

  /**
   * Sets the operational mode (MOCK_HARDWARE, HEADLESS_CLI, DIRECT_TRANSPORT).
   */
  setMode(newMode: LedgerMode): void {
    this.mode = newMode;
  }

  /**
   * Returns current Ledger device status and connection telemetry.
   */
  async getStatus(): Promise<LedgerDeviceStatus> {
    return {
      connected: true,
      mode: this.mode,
      model: DEFAULT_LEDGER_MODEL,
      address: getAddress(this.signerWallet.address),
      derivationPath: this.derivationPath,
      keyRingInitialized: true,
    };
  }

  /**
   * Returns the checksummed address of the authorized Ledger human signer.
   */
  async getSignerAddress(): Promise<string> {
    return getAddress(this.signerWallet.address);
  }

  /**
   * Translates TreasuryActionApprovalParams into transparent, human-readable clear-signing fields.
   * Eliminates blind-signing by displaying critical action attributes.
   */
  formatClearSignPrompt(
    approval: TreasuryActionApprovalParams,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): LedgerClearSignPrompt {
    const digest = this.eip712Service.computeDigest(approval, domain);

    // Format human-readable amount (assume 6 decimals for standard USDC)
    const rawAmountBigInt = BigInt(approval.amount);
    const formattedAmount = (Number(rawAmountBigInt) / 1e6).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 6,
    });

    const fields: LedgerClearSignField[] = [
      {
        label: 'Action ID',
        value: approval.actionId,
        critical: false,
      },
      {
        label: 'Transfer Amount',
        value: `$${formattedAmount} (${rawAmountBigInt.toString()} units)`,
        critical: true,
      },
      {
        label: 'Recipient',
        value: getAddress(approval.recipient),
        critical: true,
      },
      {
        label: 'Token Asset',
        value: getAddress(approval.token),
        critical: false,
      },
      {
        label: 'Risk Score',
        value: `${approval.riskScore} / 100 (${approval.riskScore >= 75 ? 'HIGH RISK' : 'ELEVATED'})`,
        critical: true,
      },
      {
        label: 'Approval Nonce',
        value: approval.nonce.toString(),
        critical: false,
      },
      {
        label: 'Deadline (UTC)',
        value: new Date(Number(approval.deadline) * 1000).toISOString(),
        critical: true,
      },
      {
        label: 'Mandate Hash',
        value: approval.mandateHash,
        critical: false,
      },
    ];

    return {
      title: CLEAR_SIGN_TITLE,
      fields,
      domain: `${domain.name} v${domain.version} (Chain: ${domain.chainId})`,
      digest,
      rawApproval: approval,
    };
  }

  /**
   * Signs an escalated TreasuryActionApproval payload.
   * Produces valid EIP-712 signature and ABI-encoded Safe execution payload.
   */
  async signApproval(
    approval: TreasuryActionApprovalParams,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): Promise<KeyRingSignResult> {
    const digest = this.eip712Service.computeDigest(approval, domain);

    let signature: string;

    if (this.mode === 'HEADLESS_CLI') {
      try {
        signature = await this.signViaCli(digest);
      } catch (error) {
        this.logger.warn(`CLI signing failed, falling back to secure key ring: ${error.message}`);
        signature = await this.signViaSoftwareKeyRing(approval, domain);
      }
    } else {
      signature = await this.signViaSoftwareKeyRing(approval, domain);
    }

    // Verify signature passes Eip712Service validation
    const isValid = this.eip712Service.verifySignature(
      approval,
      signature,
      this.signerWallet.address,
      domain,
    );

    if (!isValid) {
      throw new BadRequestException('Generated signature failed cryptographic verification against humanSigner');
    }

    // ABI encode payload for Safe.execTransaction()
    const encodedPayload = this.eip712Service.encodeEscalatedPayload(approval, signature);

    return {
      signature,
      signer: getAddress(this.signerWallet.address),
      digest,
      encodedPayload,
      timestamp: Date.now(),
    };
  }

  /**
   * Verifies that a given signature for an action was produced by this Ledger signer.
   */
  async verifyLedgerSignature(
    approval: TreasuryActionApprovalParams,
    signature: string,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): Promise<boolean> {
    return this.eip712Service.verifySignature(
      approval,
      signature,
      this.signerWallet.address,
      domain,
    );
  }

  /**
   * Ledger Key Ring Protocol (LKRP): Encrypts an agent secret or credential using AES-256-GCM.
   */
  async encryptSecret(keyName: string, plaintext: string): Promise<KeyRingSecret> {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', this.masterRingKey, iv);

    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');

    const combinedCiphertext = `${iv.toString('hex')}:${authTag}:${encrypted}`;

    const secret: KeyRingSecret = {
      keyName,
      ciphertext: combinedCiphertext,
      algorithm: 'AES-256-GCM',
      createdAt: new Date(),
    };

    this.secretVault.set(keyName, secret);
    return secret;
  }

  /**
   * Ledger Key Ring Protocol (LKRP): Decrypts an agent secret using AES-256-GCM.
   */
  async decryptSecret(secret: KeyRingSecret): Promise<string> {
    const [ivHex, authTagHex, encryptedHex] = secret.ciphertext.split(':');
    if (!ivHex || !authTagHex || !encryptedHex) {
      throw new BadRequestException('Malformed Key Ring ciphertext payload');
    }

    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', this.masterRingKey, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  }

  /**
   * Lists all keys managed in the local Key Ring secret vault.
   */
  async listKeys(): Promise<string[]> {
    return Array.from(this.secretVault.keys());
  }

  /**
   * Executes a command against the Ledger wallet-cli binary.
   */
  async executeCliCommand(subcommand: string, args: string[]): Promise<string> {
    return new Promise((resolve, reject) => {
      const proc = spawn(this.cliBinaryPath, [subcommand, ...args]);
      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (chunk) => {
        stdout += chunk.toString();
      });

      proc.stderr.on('data', (chunk) => {
        stderr += chunk.toString();
      });

      proc.on('close', (code) => {
        if (code === 0) {
          resolve(stdout.trim());
        } else {
          reject(new Error(`wallet-cli exited with code ${code}: ${stderr || stdout}`));
        }
      });

      proc.on('error', (err) => {
        reject(new Error(`Failed to spawn wallet-cli process: ${err.message}`));
      });
    });
  }

  private async signViaSoftwareKeyRing(
    approval: TreasuryActionApprovalParams,
    domain: Eip712Domain,
  ): Promise<string> {
    return this.signerWallet.signTypedData(
      {
        name: domain.name,
        version: domain.version,
        chainId: BigInt(domain.chainId),
        verifyingContract: getAddress(domain.verifyingContract),
      },
      EIP712_ACTION_APPROVAL_TYPES,
      {
        actionId: approval.actionId,
        agent: getAddress(approval.agent),
        recipient: getAddress(approval.recipient),
        token: getAddress(approval.token),
        amount: BigInt(approval.amount),
        nonce: BigInt(approval.nonce),
        deadline: BigInt(approval.deadline),
        mandateHash: approval.mandateHash,
        riskScore: Number(approval.riskScore),
      },
    );
  }

  private async signViaCli(digest: string): Promise<string> {
    return this.executeCliCommand('ring', ['sign', '--digest', digest]);
  }
}
