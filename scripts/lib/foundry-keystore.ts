import { spawn } from 'node:child_process';
import { basename, dirname } from 'node:path';

export interface DecryptWithFoundryKeystoreOptions {
  /** Path to the encrypted JSON keystore created by `cast wallet new` or `cast wallet import`. */
  keystoreFile: string;
}

const PRIVATE_KEY_PATTERN = /0x[0-9a-fA-F]{64}/g;

/**
 * Decrypts a test agent key from a password-encrypted Foundry keystore
 * (`cast wallet decrypt-keystore`), for exercising the x402 payment rail on a
 * machine without the Ledger. The password is passed to cast through its
 * `CAST_UNSAFE_PASSWORD` environment variable, never as a command-line
 * argument, and the key is never written to disk, logged, or included in errors.
 */
export async function decryptWithFoundryKeystore(
  options: DecryptWithFoundryKeystoreOptions,
): Promise<string> {
  const password = process.env.AGENT_KEYSTORE_PASSWORD;
  if (!password) {
    throw new Error(
      'AGENT_KEYSTORE_PASSWORD is required to decrypt the Foundry keystore agent key. ' +
        'Set it from the macOS Keychain entry, e.g. ' +
        'AGENT_KEYSTORE_PASSWORD=$(security find-generic-password -a default -s chapter2-test-agent -w).',
    );
  }

  const stdout = await runDecryptKeystore(options.keystoreFile, password);
  const matches = stdout.match(PRIVATE_KEY_PATTERN) ?? [];
  if (matches.length !== 1) {
    throw new Error(
      'cast wallet decrypt-keystore did not return exactly one 32-byte private key. ' +
        'Check that AGENT_KEYSTORE_FILE points at the keystore file created by cast.',
    );
  }
  return matches[0];
}

function runDecryptKeystore(keystoreFile: string, password: string): Promise<string> {
  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawn(
        'cast',
        ['wallet', 'decrypt-keystore', basename(keystoreFile), '--keystore-dir', dirname(keystoreFile)],
        { shell: false, env: { ...process.env, CAST_UNSAFE_PASSWORD: password } },
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
        const stderr = Buffer.concat(stderrChunks).toString('utf8').replace(PRIVATE_KEY_PATTERN, '<redacted>').trim();
        reject(
          new Error(
            `cast wallet decrypt-keystore exited with code ${code}${stderr ? `: ${stderr}` : ' (no error output)'}`,
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
    return new Error('cast is not installed or not on PATH. Install Foundry: https://getfoundry.sh');
  }
  const message = err instanceof Error ? err.message : String(err);
  return new Error(`Failed to spawn cast: ${message}`);
}
