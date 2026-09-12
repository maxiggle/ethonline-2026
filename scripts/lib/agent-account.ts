import { privateKeyToAccount, type PrivateKeyAccount } from 'viem/accounts';

import { decryptWithLedgerKeyRing } from './ledger-key-ring.js';

/**
 * Loads the Chapter 2 autonomous agent's viem account by decrypting its
 * private key from the Ledger Key Ring. The key never touches disk in
 * plaintext form; it exists only for the lifetime of the returned account.
 */
export async function loadAgentAccount(): Promise<PrivateKeyAccount> {
  const inputFile = requireEnv('AGENT_KEY_RING_FILE');
  const keyName = requireEnv('AGENT_KEY_RING_KEY_NAME');

  const privateKey = await decryptWithLedgerKeyRing({ inputFile, keyName });
  return privateKeyToAccount(privateKey as `0x${string}`);
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required to load the agent account.`);
  }
  return value;
}
