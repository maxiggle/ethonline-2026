import { getAddress } from 'ethers';

export interface X402Config {
  network: 'eip155:84532';
  facilitatorUrl: string;
  usdcAddress: string;
  payToAddress: string;
  partnerPayToAddress: string;
  publicBaseUrl: string;
  approvedPayTo: string[];
  autonomousLimit: bigint;
  dailyLimit: bigint;
  ledgerApproverAddress: string;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value.trim();
}

function requireAddress(name: string): string {
  const value = requireEnv(name);
  try {
    return getAddress(value);
  } catch {
    throw new Error(`Environment variable ${name} is not a valid Ethereum address: '${value}'`);
  }
}

function requireAddressList(name: string): string[] {
  const raw = requireEnv(name);
  const entries = raw
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
  if (entries.length === 0) {
    throw new Error(`Environment variable ${name} must contain at least one address`);
  }
  return entries.map((entry) => {
    try {
      return getAddress(entry);
    } catch {
      throw new Error(`Environment variable ${name} contains an invalid address: '${entry}'`);
    }
  });
}

function requirePositiveBigInt(name: string): bigint {
  const value = requireEnv(name);
  let parsed: bigint;
  try {
    parsed = BigInt(value);
  } catch {
    throw new Error(`Environment variable ${name} must be an integer (atomic units), got '${value}'`);
  }
  if (parsed <= 0n) {
    throw new Error(`Environment variable ${name} must be a positive integer, got '${value}'`);
  }
  return parsed;
}

/**
 * Loads and validates the x402 v2 seller and Guardian spending-policy configuration. Throws
 * immediately on any missing or malformed value; there are no fallbacks.
 */
export function loadX402Config(): X402Config {
  const network = requireEnv('X402_NETWORK');
  if (network !== 'eip155:84532') {
    throw new Error(`X402_NETWORK must be 'eip155:84532' (Base Sepolia), got '${network}'`);
  }

  const facilitatorUrl = requireEnv('X402_FACILITATOR_URL');
  try {
    new URL(facilitatorUrl);
  } catch {
    throw new Error(`X402_FACILITATOR_URL is not a valid URL: '${facilitatorUrl}'`);
  }

  const publicBaseUrl = requireEnv('PUBLIC_BASE_URL');
  try {
    new URL(publicBaseUrl);
  } catch {
    throw new Error(`PUBLIC_BASE_URL is not a valid URL: '${publicBaseUrl}'`);
  }

  const payToAddress = requireAddress('X402_PAY_TO_ADDRESS');
  const partnerPayToAddress = requireAddress('X402_PARTNER_PAY_TO_ADDRESS');
  const approvedPayTo = requireAddressList('X402_APPROVED_PAY_TO');

  if (!approvedPayTo.includes(payToAddress)) {
    throw new Error(`X402_APPROVED_PAY_TO must include X402_PAY_TO_ADDRESS (${payToAddress})`);
  }
  if (approvedPayTo.includes(partnerPayToAddress)) {
    throw new Error(
      `X402_APPROVED_PAY_TO must not include X402_PARTNER_PAY_TO_ADDRESS (${partnerPayToAddress})`,
    );
  }

  return {
    network,
    facilitatorUrl,
    usdcAddress: requireAddress('USDC_ADDRESS'),
    payToAddress,
    partnerPayToAddress,
    publicBaseUrl: publicBaseUrl.replace(/\/+$/, ''),
    approvedPayTo,
    autonomousLimit: requirePositiveBigInt('X402_AUTONOMOUS_LIMIT'),
    dailyLimit: requirePositiveBigInt('X402_DAILY_LIMIT'),
    ledgerApproverAddress: requireAddress('LEDGER_APPROVER_ADDRESS'),
  };
}
