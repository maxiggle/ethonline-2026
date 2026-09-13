import { signedAgentFetch, type AgentRequestSigner } from './agent-request.js';
import { serializeBigInts } from './serialize-typed-data.js';

/** The EIP-712 typed-data shape `ClientEvmSigner.signTypedData` receives from `@x402/evm`. */
export interface EvmTypedData {
  domain: Record<string, unknown>;
  types: Record<string, unknown>;
  primaryType: string;
  message: Record<string, unknown>;
}

export interface LedgerRemoteSignerOptions {
  /** The human's Ledger Ethereum address, from `GET /x402/approvals/config`. */
  approverAddress: `0x${string}`;
  /** The `TreasuryAction` id this escalation belongs to, from `POST /x402/payments/authorize`. */
  actionId: string;
  /** The Key Ring agent account, used to sign the escalation POST and status polls. */
  agentAccount: AgentRequestSigner;
  baseUrl: string;
  /** Injectable for tests; defaults to `signedAgentFetch`. */
  agentFetch?: typeof signedAgentFetch;
  /** Injectable for tests; defaults to a real timer. */
  sleep?: (ms: number) => Promise<void>;
  /** Injectable clock (ms) for tests; defaults to `Date.now()`. */
  now?: () => number;
  pollIntervalMs?: number;
  /** Upper bound on the wait, further capped by the typed data's own `validBefore`. */
  maxWaitMs?: number;
  /** Called once the typed data has been posted and polling is about to start. */
  onWaiting?: () => void;
}

const DEFAULT_POLL_INTERVAL_MS = 3_000;
const DEFAULT_MAX_WAIT_MS = 10 * 60 * 1000;

/**
 * Builds a `ClientEvmSigner` for `registerExactEvmScheme` that never holds a private key: signing
 * a payment authorization means posting the typed data to the Guardian escalation queue and
 * polling for the human's Ledger-signed result. Resolves with the signature once
 * `escalationStatus` is `SIGNED`, throws once it is `REJECTED`, and throws if the typed data's own
 * `validBefore` (or the configured `maxWaitMs`, whichever comes first) elapses first.
 */
export function createLedgerRemoteSigner(options: LedgerRemoteSignerOptions): {
  address: `0x${string}`;
  signTypedData(typedData: EvmTypedData): Promise<`0x${string}`>;
} {
  const agentFetch = options.agentFetch ?? signedAgentFetch;
  const now = options.now ?? (() => Date.now());
  const sleep = options.sleep ?? ((ms: number) => new Promise((resolve) => setTimeout(resolve, ms)));
  const pollIntervalMs = options.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS;
  const maxWaitMs = options.maxWaitMs ?? DEFAULT_MAX_WAIT_MS;

  return {
    address: options.approverAddress,
    async signTypedData(typedData: EvmTypedData): Promise<`0x${string}`> {
      const escalationResponse = await agentFetch(
        options.agentAccount,
        options.baseUrl,
        'POST',
        `/x402/payments/${options.actionId}/escalation`,
        { typedData: serializeBigInts(typedData) },
      );
      if (!escalationResponse.ok) {
        const errorBody = await escalationResponse.text();
        throw new Error(
          `Failed to submit escalation for action ${options.actionId}: ${escalationResponse.status} ${errorBody}`,
        );
      }

      options.onWaiting?.();

      const validBeforeSeconds = Number(typedData.message.validBefore);
      const nowSeconds = Math.floor(now() / 1000);
      const secondsUntilExpiry = Number.isFinite(validBeforeSeconds)
        ? validBeforeSeconds - nowSeconds
        : maxWaitMs / 1000;
      const effectiveMaxWaitMs = Math.max(0, Math.min(maxWaitMs, secondsUntilExpiry * 1000));
      const deadline = now() + effectiveMaxWaitMs;

      while (true) {
        if (now() >= deadline) {
          throw new Error(
            `Timed out waiting for the Ledger approval on action ${options.actionId}: the payment ` +
              `authorization's validBefore window elapsed before a human signed it. Re-run the scenario.`,
          );
        }

        await sleep(pollIntervalMs);

        const statusResponse = await agentFetch(
          options.agentAccount,
          options.baseUrl,
          'GET',
          `/x402/payments/${options.actionId}`,
        );
        if (!statusResponse.ok) {
          const errorBody = await statusResponse.text();
          throw new Error(
            `Failed to poll status for action ${options.actionId}: ${statusResponse.status} ${errorBody}`,
          );
        }
        const status = (await statusResponse.json()) as {
          escalationStatus?: string;
          signature?: `0x${string}`;
        };

        if (status.escalationStatus === 'SIGNED') {
          if (!status.signature) {
            throw new Error(`Action ${options.actionId} is SIGNED but carries no signature`);
          }
          return status.signature;
        }
        if (status.escalationStatus === 'REJECTED') {
          throw new Error(`Escalation for action ${options.actionId} was rejected by the human approver`);
        }
      }
    },
  };
}
