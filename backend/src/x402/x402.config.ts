import { getAddress } from 'ethers';

export interface X402Config {
  network: 'eip155:84532';
  facilitatorUrl: string;
  usdcAddress: string;
  payToAddress: string;
  partnerPayToAddress: string;
  publicBaseUrl: string;
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

/**
 * Loads and validates the x402 v2 seller configuration. Throws immediately on any missing
 * or malformed value; there are no fallbacks.
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

  return {
    network,
    facilitatorUrl,
    usdcAddress: requireAddress('USDC_ADDRESS'),
    payToAddress: requireAddress('X402_PAY_TO_ADDRESS'),
    partnerPayToAddress: requireAddress('X402_PARTNER_PAY_TO_ADDRESS'),
    publicBaseUrl: publicBaseUrl.replace(/\/+$/, ''),
  };
}
