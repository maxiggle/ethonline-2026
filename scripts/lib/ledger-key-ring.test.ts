import { EventEmitter } from 'node:events';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const MOCK_PRIVATE_KEY = '0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

class FakeChildProcess extends EventEmitter {
  stdout = new EventEmitter();
  stderr = new EventEmitter();
}

vi.mock('node:child_process', () => ({
  spawn: vi.fn(),
}));

const { spawn } = await import('node:child_process');
const { decryptWithLedgerKeyRing } = await import('./ledger-key-ring.js');

const spawnMock = vi.mocked(spawn);

function emitSuccess(stdout: string) {
  const child = new FakeChildProcess();
  spawnMock.mockReturnValueOnce(child as never);
  queueMicrotask(() => {
    child.stdout.emit('data', Buffer.from(stdout));
    child.emit('close', 0);
  });
  return child;
}

function emitFailure(code: number, stderr: string) {
  const child = new FakeChildProcess();
  spawnMock.mockReturnValueOnce(child as never);
  queueMicrotask(() => {
    if (stderr) child.stderr.emit('data', Buffer.from(stderr));
    child.emit('close', code);
  });
  return child;
}

function emitSpawnError(code: string) {
  const child = new FakeChildProcess();
  spawnMock.mockReturnValueOnce(child as never);
  queueMicrotask(() => {
    const err = Object.assign(new Error('spawn wallet-cli ENOENT'), { code });
    child.emit('error', err);
  });
  return child;
}

describe('decryptWithLedgerKeyRing', () => {
  const baseEnv = { ...process.env };

  beforeEach(() => {
    process.env = { ...baseEnv, WALLET_PASS: 'ring-password' };
    spawnMock.mockReset();
  });

  afterEach(() => {
    process.env = { ...baseEnv };
  });

  it('resolves the decrypted private key on success', async () => {
    emitSuccess(`${MOCK_PRIVATE_KEY}\n`);

    const result = await decryptWithLedgerKeyRing({
      inputFile: '~/.chapter2/agent-key.enc',
      keyName: 'chapter2-x402-agent',
    });

    expect(result).toBe(MOCK_PRIVATE_KEY);
    expect(spawnMock).toHaveBeenCalledWith(
      'wallet-cli',
      ['ring', 'decrypt', '--input', '~/.chapter2/agent-key.enc', '--key', 'chapter2-x402-agent'],
      expect.objectContaining({ shell: false }),
    );
  });

  it('adds the 0x prefix when the ring omits it', async () => {
    emitSuccess(MOCK_PRIVATE_KEY.slice(2));

    const result = await decryptWithLedgerKeyRing({
      inputFile: 'key.enc',
      keyName: 'agent',
    });

    expect(result).toBe(MOCK_PRIVATE_KEY);
  });

  it('rejects when WALLET_PASS is missing', async () => {
    delete process.env.WALLET_PASS;

    await expect(
      decryptWithLedgerKeyRing({ inputFile: 'key.enc', keyName: 'agent' }),
    ).rejects.toThrow(/WALLET_PASS/);
    expect(spawnMock).not.toHaveBeenCalled();
  });

  it('maps ENOENT to a clear "not installed" error', async () => {
    emitSpawnError('ENOENT');

    await expect(
      decryptWithLedgerKeyRing({ inputFile: 'key.enc', keyName: 'agent' }),
    ).rejects.toThrow(/not installed/);
  });

  it('surfaces stderr without the secret on a non-zero exit', async () => {
    emitFailure(1, 'wrong ring password');

    const error = await decryptWithLedgerKeyRing({
      inputFile: 'key.enc',
      keyName: 'agent',
    }).catch((err: Error) => err);

    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toMatch(/wrong ring password/);
    expect((error as Error).message).not.toContain(MOCK_PRIVATE_KEY);
  });

  it('rejects malformed output without ever including it in the error verbatim as a key', async () => {
    emitSuccess('not-a-private-key');

    const error = await decryptWithLedgerKeyRing({
      inputFile: 'key.enc',
      keyName: 'agent',
    }).catch((err: Error) => err);

    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toMatch(/did not return a 32-byte private key/);
  });
});
