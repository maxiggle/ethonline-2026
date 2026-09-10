import { Injectable, BadRequestException } from '@nestjs/common';
import {
  TypedDataEncoder,
  AbiCoder,
  getAddress,
  verifyTypedData,
  keccak256,
  toUtf8Bytes,
} from 'ethers';
import {
  Eip712Domain,
  TreasuryActionApprovalParams,
  Eip712TypedData,
  EscalatedExecutionPayload,
} from './interfaces/eip712.interface';
import {
  ACTION_APPROVAL_PRIMARY_TYPE,
  EIP712_ACTION_APPROVAL_TYPES,
  DEFAULT_BASE_SEPOLIA_DOMAIN,
  ESCALATED_ACTION_APPROVAL_ABI_TYPE,
} from './eip712.constants';

@Injectable()
export class Eip712Service {
  private readonly abiCoder = AbiCoder.defaultAbiCoder();

  /**
   * Generates a fully compliant EIP-712 Typed Data envelope for wallet signing.
   */
  generateTypedData(
    params: TreasuryActionApprovalParams,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): Eip712TypedData {
    const formattedDomain = this.formatDomain(domain);
    const message = this.formatMessage(params);

    return {
      domain: formattedDomain,
      types: EIP712_ACTION_APPROVAL_TYPES,
      primaryType: ACTION_APPROVAL_PRIMARY_TYPE,
      message,
    };
  }

  /**
   * Computes the 32-byte EIP-712 Domain Separator matching Chapter2Guard.DOMAIN_SEPARATOR().
   */
  computeDomainSeparator(domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN): string {
    const formattedDomain = this.formatDomain(domain);
    return TypedDataEncoder.hashDomain(formattedDomain);
  }

  /**
   * Computes the struct hash for TreasuryActionApproval.
   */
  computeStructHash(params: TreasuryActionApprovalParams): string {
    const message = this.formatMessage(params);
    return TypedDataEncoder.from(EIP712_ACTION_APPROVAL_TYPES).hash(message);
  }

  /**
   * Computes the final 32-byte EIP-712 signing digest:
   * keccak256("\x19\x01" || domainSeparator || structHash)
   */
  computeDigest(
    params: TreasuryActionApprovalParams,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): string {
    const formattedDomain = this.formatDomain(domain);
    const message = this.formatMessage(params);
    return TypedDataEncoder.hash(formattedDomain, EIP712_ACTION_APPROVAL_TYPES, message);
  }

  /**
   * Recovers the signing Ethereum address from an EIP-712 signature.
   */
  recoverSigner(
    params: TreasuryActionApprovalParams,
    signature: string,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): string {
    try {
      const formattedDomain = this.formatDomain(domain);
      const message = this.formatMessage(params);
      return verifyTypedData(formattedDomain, EIP712_ACTION_APPROVAL_TYPES, message, signature);
    } catch (error) {
      throw new BadRequestException(`Failed to recover signer from signature: ${error.message}`);
    }
  }

  /**
   * Verifies that the recovered signature matches the authorized humanSigner address.
   */
  verifySignature(
    params: TreasuryActionApprovalParams,
    signature: string,
    expectedSigner: string,
    domain: Eip712Domain = DEFAULT_BASE_SEPOLIA_DOMAIN,
  ): boolean {
    if (!signature || !expectedSigner) {
      return false;
    }

    try {
      const recovered = this.recoverSigner(params, signature, domain);
      return getAddress(recovered) === getAddress(expectedSigner);
    } catch {
      return false;
    }
  }

  /**
   * ABI encodes the TreasuryActionApproval struct and 65-byte signature
   * into the exact payload expected by Chapter2Guard.checkTransaction() / Safe.execTransaction().
   */
  encodeEscalatedPayload(
    params: TreasuryActionApprovalParams,
    signature: string,
  ): string {
    const formattedParams = this.formatMessage(params);
    const tupleValues = [
      formattedParams.actionId,
      formattedParams.agent,
      formattedParams.recipient,
      formattedParams.token,
      formattedParams.amount,
      formattedParams.nonce,
      formattedParams.deadline,
      formattedParams.mandateHash,
      formattedParams.riskScore,
    ];

    return this.abiCoder.encode(
      [ESCALATED_ACTION_APPROVAL_ABI_TYPE, 'bytes'],
      [tupleValues, signature],
    );
  }

  /**
   * Decodes an escalated payload back into approval parameters and raw signature.
   */
  decodeEscalatedPayload(payloadHex: string): EscalatedExecutionPayload {
    try {
      const [decodedApproval, signature] = this.abiCoder.decode(
        [ESCALATED_ACTION_APPROVAL_ABI_TYPE, 'bytes'],
        payloadHex,
      );

      return {
        approval: {
          actionId: decodedApproval[0],
          agent: decodedApproval[1],
          recipient: decodedApproval[2],
          token: decodedApproval[3],
          amount: decodedApproval[4].toString(),
          nonce: decodedApproval[5].toString(),
          deadline: decodedApproval[6].toString(),
          mandateHash: decodedApproval[7],
          riskScore: Number(decodedApproval[8]),
        },
        signature,
      };
    } catch (error) {
      throw new BadRequestException(`Failed to decode escalated execution payload: ${error.message}`);
    }
  }

  private formatDomain(domain: Eip712Domain): Eip712Domain {
    return {
      name: domain.name,
      version: domain.version,
      chainId: BigInt(domain.chainId),
      verifyingContract: getAddress(domain.verifyingContract),
    };
  }

  private formatMessage(params: TreasuryActionApprovalParams): Record<string, any> {
    return {
      actionId: params.actionId,
      agent: getAddress(params.agent),
      recipient: getAddress(params.recipient),
      token: getAddress(params.token),
      amount: BigInt(params.amount),
      nonce: BigInt(params.nonce),
      deadline: BigInt(params.deadline),
      mandateHash: params.mandateHash,
      riskScore: Number(params.riskScore),
    };
  }
}
