import { describe, expect, it } from "vitest";
import { assembleEip191Signature, rejectionMessage, withEip712DomainType } from "./signature";
import type { EscalationTypedData } from "./types";

describe("assembleEip191Signature", () => {
  it("pads short r/s hex to 32 bytes and keeps v as-is when already 27/28", () => {
    const signature = assembleEip191Signature({ r: "0x1", s: "0x2", v: 28 });
    expect(signature).toBe(`0x${"0".repeat(63)}1${"0".repeat(63)}21c`);
  });

  it("strips a 0x prefix before padding", () => {
    const r = "a".repeat(64);
    const s = "b".repeat(64);
    const signature = assembleEip191Signature({ r: `0x${r}`, s, v: 27 });
    expect(signature).toBe(`0x${r}${s}1b`);
  });

  it("normalizes a 0/1 recovery id to 27/28", () => {
    const r = "1".repeat(64);
    const s = "2".repeat(64);
    expect(assembleEip191Signature({ r, s, v: 0 })).toBe(`0x${r}${s}1b`);
    expect(assembleEip191Signature({ r, s, v: 1 })).toBe(`0x${r}${s}1c`);
  });

  it("rejects a recovery id it does not recognize", () => {
    expect(() => assembleEip191Signature({ r: "0x1", s: "0x2", v: 4 })).toThrow(/recovery id/);
  });

  it("rejects an oversized r or s component", () => {
    expect(() => assembleEip191Signature({ r: "1".repeat(65), s: "0x1", v: 27 })).toThrow(/exceeds 32 bytes/);
  });
});

describe("withEip712DomainType", () => {
  const baseTypedData: EscalationTypedData = {
    domain: {
      name: "USD Coin",
      version: "2",
      chainId: 84532,
      verifyingContract: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
    },
    types: {
      TransferWithAuthorization: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "value", type: "uint256" },
        { name: "validAfter", type: "uint256" },
        { name: "validBefore", type: "uint256" },
        { name: "nonce", type: "bytes32" },
      ],
    },
    primaryType: "TransferWithAuthorization",
    message: {
      from: "0xF1",
      to: "0xF2",
      value: "1000000",
      validAfter: "0",
      validBefore: "9999999999",
      nonce: "0xabc",
    },
  };

  it("adds an EIP712Domain type built from the domain fields present", () => {
    const result = withEip712DomainType(baseTypedData);
    expect(result.types.EIP712Domain).toEqual([
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
    ]);
    expect(result.types.TransferWithAuthorization).toBe(baseTypedData.types.TransferWithAuthorization);
  });

  it("omits domain fields that are not present", () => {
    const result = withEip712DomainType({
      ...baseTypedData,
      domain: { chainId: 84532, verifyingContract: baseTypedData.domain.verifyingContract },
    });
    expect(result.types.EIP712Domain).toEqual([
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
    ]);
  });

  it("leaves typed data untouched when EIP712Domain is already present", () => {
    const withDomain: EscalationTypedData = {
      ...baseTypedData,
      types: { ...baseTypedData.types, EIP712Domain: [{ name: "name", type: "string" }] },
    };
    expect(withEip712DomainType(withDomain)).toBe(withDomain);
  });
});

describe("rejectionMessage", () => {
  it("matches the backend's expected personal_sign message", () => {
    expect(rejectionMessage("action-123")).toBe("chapter2-reject:action-123");
  });
});
