const USDC_DECIMALS = 6;

export function formatUsdcAmount(atomicAmount: string): string {
  const amount = BigInt(atomicAmount);
  const divisor = 10n ** BigInt(USDC_DECIMALS);
  const whole = amount / divisor;
  const fraction = (amount % divisor).toString().padStart(USDC_DECIMALS, "0").replace(/0+$/, "");
  return fraction.length > 0 ? `${whole}.${fraction} USDC` : `${whole} USDC`;
}

export function formatValidBefore(validBefore: unknown): string {
  const seconds = typeof validBefore === "string" ? Number(validBefore) : Number(validBefore ?? NaN);
  if (!Number.isFinite(seconds)) {
    return "unknown";
  }
  return new Date(seconds * 1000).toLocaleString();
}

export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}
