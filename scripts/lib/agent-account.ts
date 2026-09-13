import { privateKeyToAccount, type PrivateKeyAccount } from 'viem/accounts';

import { decryptWithFoundryKeystore } from './foundry-keystore.js';
import { decryptWithLedgerKeyRing } from './ledger-key-ring.js';

export const AGENT_KEY_SOURCES = ['ledger-key-ring', 'foundry-keystore'] as const;
export type AgentKeySource = (typeof AGENT_KEY_SOURCES)[number];

/**
 * Loads the Chapter 2 autonomous agent's viem account from the key source named
 * by the required AGENT_KEY_SOURCE, with no default:
 * - `ledger-key-ring`: the demo path, decrypted with the Ledger Key Ring (`wallet-cli ring`).
 * - `foundry-keystore`: a password-encrypted test key, for exercising the payment rail
 *   on a machine without the Ledger.
 * The key never touches disk in plaintext form; it exists only for the lifetime of the
 * returned account.
 */
export async function loadAgentAccount(): Promise<PrivateKeyAccount> {
  const source = requireEnv('AGENT_KEY_SOURCE');
  const privateKey = await decryptAgentKey(source);
  return privateKeyToAccount(privateKey as `0x${string}`);
}

function decryptAgentKey(source: string): Promise<string> {
  if (source === 'ledger-key-ring') {
    return decryptWithLedgerKeyRing({
      inputFile: requireEnv('AGENT_KEY_RING_FILE'),
      keyName: requireEnv('AGENT_KEY_RING_KEY_NAME'),
    });
  }
  if (source === 'foundry-keystore') {
    return decryptWithFoundryKeystore({ keystoreFile: requireEnv('AGENT_KEYSTORE_FILE') });
  }
  throw new Error(`AGENT_KEY_SOURCE must be one of ${AGENT_KEY_SOURCES.join(', ')}; got '${source}'.`);
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required to load the agent account.`);
  }
  return value;
}
