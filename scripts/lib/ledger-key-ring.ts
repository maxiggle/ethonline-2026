import { spawn } from 'node:child_process';

export interface DecryptWithLedgerKeyRingOptions {
  /** Path to the file encrypted with `wallet-cli ring encrypt`. */
  inputFile: string;
  /** Key name the secret was encrypted under (must match `--key` at encrypt time). */
  keyName: string;
}

const PRIVATE_KEY_WITH_PREFIX = /^0x[0-9a-fA-F]{64}$/;
const PRIVATE_KEY_WITHOUT_PREFIX = /^[0-9a-fA-F]{64}$/;

/**
 * Decrypts the Chapter 2 autonomous agent's private key from the Ledger Key
 * Ring (`wallet-cli ring decrypt`). The key is held in memory only for the
 * caller's use; it is never written to disk, logged, or cached.
 */
export async function decryptWithLedgerKeyRing(
  options: DecryptWithLedgerKeyRingOptions,
): Promise<string> {
  const { inputFile, keyName } = options;

  if (!process.env.WALLET_PASS) {
    throw new Error(
      'WALLET_PASS is required to decrypt the Ledger Key Ring-protected agent key. ' +
        'Set it from the macOS Keychain entry, e.g. ' +
        'WALLET_PASS=$(security find-generic-password -a default -s ledger-wallet-cli -w).',
    );
  }

  const stdout = await runRingDecrypt(inputFile, keyName);
  const trimmed = stdout.trim();

  if (PRIVATE_KEY_WITH_PREFIX.test(trimmed)) {
    return trimmed;
  }
  if (PRIVATE_KEY_WITHOUT_PREFIX.test(trimmed)) {
    return `0x${trimmed}`;
  }

  throw new Error(
    'wallet-cli ring decrypt did not return a 32-byte private key. ' +
      'Check that the ring file and key name match what was used at encrypt time.',
  );
}

function runRingDecrypt(inputFile: string, keyName: string): Promise<string> {
  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawn(
        'wallet-cli',
        ['ring', 'decrypt', '--input', inputFile, '--key', keyName],
        { shell: false, env: process.env },
      );
    } catch (err) {
      reject(mapSpawnError(err));
      return;
    }

    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];

    child.stdout?.on('data', (chunk: Buffer) => stdoutChunks.push(chunk));
    child.stderr?.on('data', (chunk: Buffer) => stderrChunks.push(chunk));

    child.on('error', (err) => reject(mapSpawnError(err)));

    child.on('close', (code) => {
      if (code !== 0) {
        const stderr = Buffer.concat(stderrChunks).toString('utf8').trim();
        reject(
          new Error(
            `wallet-cli ring decrypt exited with code ${code}${
              stderr ? `: ${stderr}` : ' (no error output)'
            }`,
          ),
        );
        return;
      }
      resolve(Buffer.concat(stdoutChunks).toString('utf8'));
    });
  });
}

function mapSpawnError(err: unknown): Error {
  if (err instanceof Error && (err as NodeJS.ErrnoException).code === 'ENOENT') {
    return new Error(
      'wallet-cli is not installed or not on PATH. Install it with `npm i -g @ledgerhq/wallet-cli`.',
    );
  }
  const message = err instanceof Error ? err.message : String(err);
  return new Error(`Failed to spawn wallet-cli: ${message}`);
}
