import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { privateKeyToAccount } from 'viem/accounts';

const TEST_PRIVATE_KEY = '0x305d73521f6f7cac48c5abfcfe501e9068bcfff3ce73f0fcab1439cd88cea301';

vi.mock('./ledger-key-ring.js', () => ({ decryptWithLedgerKeyRing: vi.fn() }));
vi.mock('./foundry-keystore.js', () => ({ decryptWithFoundryKeystore: vi.fn() }));

const { decryptWithLedgerKeyRing } = await import('./ledger-key-ring.js');
const { decryptWithFoundryKeystore } = await import('./foundry-keystore.js');
const { loadAgentAccount } = await import('./agent-account.js');

const ledgerMock = vi.mocked(decryptWithLedgerKeyRing);
const foundryMock = vi.mocked(decryptWithFoundryKeystore);
const expectedAddress = privateKeyToAccount(TEST_PRIVATE_KEY).address;

describe('loadAgentAccount', () => {
  const baseEnv = { ...process.env };

  beforeEach(() => {
    process.env = { ...baseEnv };
    delete process.env.AGENT_KEY_SOURCE;
    ledgerMock.mockReset();
    foundryMock.mockReset();
  });

  afterEach(() => {
    process.env = { ...baseEnv };
  });

  it('requires AGENT_KEY_SOURCE and never picks a source by default', async () => {
    await expect(loadAgentAccount()).rejects.toThrow(/AGENT_KEY_SOURCE is required/);
    expect(ledgerMock).not.toHaveBeenCalled();
    expect(foundryMock).not.toHaveBeenCalled();
  });

  it('rejects an unknown key source', async () => {
    process.env.AGENT_KEY_SOURCE = 'plaintext';
    await expect(loadAgentAccount()).rejects.toThrow(/must be one of ledger-key-ring, foundry-keystore/);
  });

  it('loads the agent from the Ledger Key Ring', async () => {
    process.env.AGENT_KEY_SOURCE = 'ledger-key-ring';
    process.env.AGENT_KEY_RING_FILE = '/keys/agent-key.enc';
    process.env.AGENT_KEY_RING_KEY_NAME = 'chapter2-x402-agent';
    ledgerMock.mockResolvedValueOnce(TEST_PRIVATE_KEY);

    const account = await loadAgentAccount();

    expect(account.address).toBe(expectedAddress);
    expect(ledgerMock).toHaveBeenCalledWith({ inputFile: '/keys/agent-key.enc', keyName: 'chapter2-x402-agent' });
    expect(foundryMock).not.toHaveBeenCalled();
  });

  it('loads the agent from a Foundry keystore', async () => {
    process.env.AGENT_KEY_SOURCE = 'foundry-keystore';
    process.env.AGENT_KEYSTORE_FILE = '/keystores/chapter2-test-agent';
    foundryMock.mockResolvedValueOnce(TEST_PRIVATE_KEY);

    const account = await loadAgentAccount();

    expect(account.address).toBe(expectedAddress);
    expect(foundryMock).toHaveBeenCalledWith({ keystoreFile: '/keystores/chapter2-test-agent' });
    expect(ledgerMock).not.toHaveBeenCalled();
  });

  it('requires the Key Ring file settings for the ledger-key-ring source', async () => {
    process.env.AGENT_KEY_SOURCE = 'ledger-key-ring';
    await expect(loadAgentAccount()).rejects.toThrow(/AGENT_KEY_RING_FILE is required/);
  });
});
