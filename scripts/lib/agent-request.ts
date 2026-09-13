import { createHash } from 'node:crypto';

/**
 * Minimal signer contract `signedAgentFetch` needs from an agent identity: a public address and
 * an EIP-191 `personal_sign` over an arbitrary UTF-8 message. A viem `PrivateKeyAccount` (from
 * `loadAgentAccount()`) satisfies this directly; tests can supply a plain mock instead.
 */
export interface AgentRequestSigner {
  readonly address: string;
  signMessage(args: { message: string }): Promise<string>;
}

export interface SignedAgentFetchOptions {
  /** Injectable for tests; defaults to the global `fetch`. */
  fetchImpl?: typeof fetch;
  /** Injectable clock (unix seconds) for tests; defaults to `Date.now()`. */
  now?: () => number;
}

/**
 * Signs and sends one request under the Chapter 2 `AgentSignatureGuard` scheme: EIP-191
 * `personal_sign` over `['chapter2-agent-request', METHOD, path, timestamp, sha256hex(rawBody)]`,
 * carried as `X-Agent-Address` / `X-Agent-Timestamp` / `X-Agent-Signature`. `path` must be exactly
 * the request path as the server sees it (`request.originalUrl`), query string included. Every
 * call produces a fresh, single-use signature — callers must not cache or replay the result.
 */
export async function signedAgentFetch(
  signer: AgentRequestSigner,
  baseUrl: string,
  method: string,
  path: string,
  body?: unknown,
  options: SignedAgentFetchOptions = {},
): Promise<Response> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? (() => Date.now());

  const upperMethod = method.toUpperCase();
  const rawBody = body === undefined ? '' : JSON.stringify(body);
  const bodyHash = createHash('sha256').update(Buffer.from(rawBody, 'utf8')).digest('hex');
  const timestamp = Math.floor(now() / 1000);
  const message = ['chapter2-agent-request', upperMethod, path, String(timestamp), bodyHash].join('\n');
  const signature = await signer.signMessage({ message });

  const headers: Record<string, string> = {
    'X-Agent-Address': signer.address,
    'X-Agent-Timestamp': String(timestamp),
    'X-Agent-Signature': signature,
  };
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  return fetchImpl(`${baseUrl}${path}`, {
    method: upperMethod,
    headers,
    body: body === undefined ? undefined : rawBody,
  });
}
