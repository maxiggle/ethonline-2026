import type { DeviceSignature, EscalationTypedData, TypedDataField } from "./types";

function normalizeHex32(hex: string): string {
  const stripped = hex.startsWith("0x") || hex.startsWith("0X") ? hex.slice(2) : hex;
  if (stripped.length > 64) {
    throw new Error(`hex value exceeds 32 bytes: ${hex}`);
  }
  return stripped.padStart(64, "0");
}

function normalizeRecoveryId(v: number): number {
  if (v === 27 || v === 28) return v;
  if (v === 0 || v === 1) return v + 27;
  throw new Error(`unexpected Ledger signature recovery id: ${v}`);
}

export function assembleEip191Signature(signature: DeviceSignature): `0x${string}` {
  const r = normalizeHex32(signature.r);
  const s = normalizeHex32(signature.s);
  const v = normalizeRecoveryId(signature.v).toString(16).padStart(2, "0");
  return `0x${r}${s}${v}`;
}

const EIP712_DOMAIN_FIELD_TYPES: Record<string, string> = {
  name: "string",
  version: "string",
  chainId: "uint256",
  verifyingContract: "address",
  salt: "bytes32",
};

export function withEip712DomainType(typedData: EscalationTypedData): EscalationTypedData {
  if (typedData.types.EIP712Domain) {
    return typedData;
  }
  const domainFields: TypedDataField[] = Object.keys(EIP712_DOMAIN_FIELD_TYPES)
    .filter((field) => typedData.domain[field as keyof typeof typedData.domain] !== undefined)
    .map((field) => ({ name: field, type: EIP712_DOMAIN_FIELD_TYPES[field] }));
  return {
    ...typedData,
    types: {
      ...typedData.types,
      EIP712Domain: domainFields,
    },
  };
}

export function rejectionMessage(actionId: string): string {
  return `chapter2-reject:${actionId}`;
}
