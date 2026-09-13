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
const { decryptWithFoundryKeystore } = await import('./foundry-keystore.js');

const spawnMock = vi.mocked(spawn);

function emitClose(code: number, stdout: string, stderr = '') {
  const child = new FakeChildProcess();
  spawnMock.mockReturnValueOnce(child as never);
  queueMicrotask(() => {
    if (stdout) child.stdout.emit('data', Buffer.from(stdout));
    if (stderr) child.stderr.emit('data', Buffer.from(stderr));
    child.emit('close', code);
  });
}

describe('decryptWithFoundryKeystore', () => {
  const baseEnv = { ...process.env };

  beforeEach(() => {
    process.env = { ...baseEnv, AGENT_KEYSTORE_PASSWORD: 'keystore-password' };
    spawnMock.mockReset();
  });

  afterEach(() => {
    process.env = { ...baseEnv };
  });

  it('parses the key from cast output and passes the password only through the environment', async () => {
    emitClose(0, `chapter2-test-agent's private key is: ${MOCK_PRIVATE_KEY}\n`);

    const result = await decryptWithFoundryKeystore({
      keystoreFile: '/home/agent/.foundry/keystores/chapter2-test-agent',
    });

    expect(result).toBe(MOCK_PRIVATE_KEY);
    const [command, args, options] = spawnMock.mock.calls[0];
    expect(command).toBe('cast');
    expect(args).toEqual([
      'wallet',
      'decrypt-keystore',
      'chapter2-test-agent',
      '--keystore-dir',
      '/home/agent/.foundry/keystores',
    ]);
    expect(args).not.toContain('keystore-password');
    expect(options).toEqual(
      expect.objectContaining({
        shell: false,
        env: expect.objectContaining({ CAST_UNSAFE_PASSWORD: 'keystore-password' }),
      }),
    );
  });

  it('rejects when AGENT_KEYSTORE_PASSWORD is missing', async () => {
    delete process.env.AGENT_KEYSTORE_PASSWORD;

    await expect(decryptWithFoundryKeystore({ keystoreFile: 'ks/agent' })).rejects.toThrow(
      /AGENT_KEYSTORE_PASSWORD/,
    );
    expect(spawnMock).not.toHaveBeenCalled();
  });

  it('maps ENOENT to a clear "not installed" error', async () => {
    const child = new FakeChildProcess();
    spawnMock.mockReturnValueOnce(child as never);
    queueMicrotask(() => child.emit('error', Object.assign(new Error('spawn cast ENOENT'), { code: 'ENOENT' })));

    await expect(decryptWithFoundryKeystore({ keystoreFile: 'ks/agent' })).rejects.toThrow(/not installed/);
  });

  it('surfaces a wrong-password error from cast', async () => {
    emitClose(1, '', 'Error: Mac Mismatch');

    await expect(decryptWithFoundryKeystore({ keystoreFile: 'ks/agent' })).rejects.toThrow(/Mac Mismatch/);
  });

  it('rejects output without exactly one private key and never echoes it', async () => {
    emitClose(0, 'unexpected output');

    const error = await decryptWithFoundryKeystore({ keystoreFile: 'ks/agent' }).catch((err: Error) => err);

    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toMatch(/exactly one 32-byte private key/);
    expect((error as Error).message).not.toContain('unexpected output');
  });
});
