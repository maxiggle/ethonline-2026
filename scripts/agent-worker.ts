/**
 * Chapter 2: agent worker for app-queued purchase requests.
 *
 * The app queues a purchase request (`POST /x402/purchase-requests`); this worker claims the
 * oldest QUEUED request for its agent, pays it through the same Guardian-gated x402 flow as
 * `agent-x402-client.ts` (ALLOW / ESCALATE / BLOCK), and reports progress and the final result
 * back so the app can show status and the paid response data. The agent's key never leaves this
 * machine.
 */
import { getAddress } from 'viem';

import { loadAgentAccount } from './lib/agent-account.js';
import type { AgentRequestSigner } from './lib/agent-request.js';
import { createLedgerRemoteSigner } from './lib/ledger-remote-signer.js';
import {
  payX402Resource,
  type AuthorizePaymentResponse,
  type EvmClientSignerLike,
  type PayResourceResult,
} from './lib/x402-payment-flow.js';
import { claimPurchaseRequest, reportProgress, reportResult, type PurchaseRequest } from './lib/purchase-requests.js';

interface ApprovalConfig {
  approverAddress: string;
  network: string;
  usdcAddress: string;
}

const CLAIM_POLL_INTERVAL_MS = 5_000;
const LEDGER_REJECTED_PATTERN = /rejected by the human approver/;
const LEDGER_EXPIRED_PATTERN = /validBefore window elapsed/;

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}. See docs/tickets/README.md.`);
  }
  return value.trim();
}

/**
 * Builds the path (plus a URL-encoded query string) the worker pays for. Throws when the
 * purchase request's `resourceUrl` is not on this backend, per the ticket's worker contract.
 */
export function buildResourcePath(resourceUrl: string, baseUrl: string, queryParams: Record<string, string>): string {
  if (!resourceUrl.startsWith(baseUrl)) {
    throw new Error(`resourceUrl '${resourceUrl}' is not on this backend (${baseUrl})`);
  }
  const path = resourceUrl.slice(baseUrl.length) || '/';
  const query = new URLSearchParams(queryParams).toString();
  return query ? `${path}?${query}` : path;
}

/**
 * Maps an error thrown by `payX402Resource` to the purchase-request terminal status it reports,
 * using `ledger-remote-signer.ts`'s exact error messages to tell REJECTED from EXPIRED.
 */
export function classifyWorkerError(err: unknown): { status: 'REJECTED' | 'EXPIRED' | 'FAILED'; message: string } {
  const message = err instanceof Error ? err.message : String(err);
  if (LEDGER_REJECTED_PATTERN.test(message)) {
    return { status: 'REJECTED', message };
  }
  if (LEDGER_EXPIRED_PATTERN.test(message)) {
    return { status: 'EXPIRED', message };
  }
  return { status: 'FAILED', message };
}

export interface HandlePurchaseRequestDeps {
  baseUrl: string;
  config: ApprovalConfig;
  agentAccount: AgentRequestSigner & EvmClientSignerLike;
  payResource?: typeof payX402Resource;
  log?: (line: string) => void;
}

/** Pays one claimed purchase request end to end and reports every step back to the backend. */
export async function handlePurchaseRequest(request: PurchaseRequest, deps: HandlePurchaseRequestDeps): Promise<void> {
  const log = deps.log ?? console.log;
  const pay = deps.payResource ?? payX402Resource;

  log(`Claimed ${request.id}: ${request.serviceName} (${request.resourceUrl})`);

  let resourcePath: string;
  try {
    resourcePath = buildResourcePath(request.resourceUrl, deps.baseUrl, request.queryParams);
  } catch {
    await reportResult({
      baseUrl: deps.baseUrl,
      agentAccount: deps.agentAccount,
      id: request.id,
      status: 'FAILED',
      error: 'resource is not on this backend',
    });
    log('  FAILED: resource is not on this backend');
    return;
  }

  try {
    const result: PayResourceResult = await pay({
      baseUrl: deps.baseUrl,
      network: deps.config.network,
      usdcAddress: deps.config.usdcAddress,
      resourcePath,
      justification: request.justification,
      agentAccount: deps.agentAccount,
      agentEvmSigner: deps.agentAccount,
      createLedgerSigner: (actionId: string) =>
        createLedgerRemoteSigner({
          approverAddress: getAddress(deps.config.approverAddress),
          actionId,
          agentAccount: deps.agentAccount,
          baseUrl: deps.baseUrl,
        }),
      onAuthorized: async (authorization: AuthorizePaymentResponse) => {
        await reportProgress({
          baseUrl: deps.baseUrl,
          agentAccount: deps.agentAccount,
          id: request.id,
          actionId: authorization.actionId,
          decision: authorization.decision,
          reasons: authorization.reasons,
        });
        log(`  Guardian decision: ${authorization.decision} (action ${authorization.actionId})`);
      },
      onWaitingForApproval: () => log('  Waiting for approval on Ledger console...'),
    });

    if (result.kind === 'BLOCK') {
      await reportResult({
        baseUrl: deps.baseUrl,
        agentAccount: deps.agentAccount,
        id: request.id,
        status: 'BLOCKED',
        decision: 'BLOCK',
        reasons: result.reasons,
      });
      log(`  BLOCKED: ${result.reasons.join('; ')}`);
      return;
    }

    await reportResult({
      baseUrl: deps.baseUrl,
      agentAccount: deps.agentAccount,
      id: request.id,
      status: 'PAID',
      actionId: result.actionId,
      transactionHash: result.transactionHash,
      response: result.data,
    });
    log(`  PAID: tx ${result.transactionHash}`);
  } catch (err) {
    const { status, message } = classifyWorkerError(err);
    await reportResult({
      baseUrl: deps.baseUrl,
      agentAccount: deps.agentAccount,
      id: request.id,
      status,
      error: message,
    });
    log(`  ${status}: ${message}`);
  }
}

let shuttingDown = false;

async function main(): Promise<void> {
  const baseUrl = requireEnv('API_BASE_URL').replace(/\/+$/, '');
  const keySource = requireEnv('AGENT_KEY_SOURCE');

  console.log('Chapter 2: agent purchase-request worker');
  console.log(`Backend: ${baseUrl}`);

  const agentAccount = await loadAgentAccount();
  console.log(`Agent address: ${agentAccount.address} (key source: ${keySource})`);

  const configResponse = await fetch(`${baseUrl}/x402/approvals/config`);
  if (!configResponse.ok) {
    throw new Error(`GET /x402/approvals/config failed: ${configResponse.status} ${await configResponse.text()}`);
  }
  const config = (await configResponse.json()) as ApprovalConfig;
  console.log(`Ledger approver address: ${config.approverAddress}`);
  console.log(`Network: ${config.network} | USDC: ${config.usdcAddress}`);

  process.on('SIGINT', () => {
    console.log('\nShutting down after the current request...');
    shuttingDown = true;
  });

  console.log('Waiting for purchase requests...');
  while (!shuttingDown) {
    const request = await claimPurchaseRequest({ baseUrl, agentAccount });
    if (!request) {
      await new Promise((resolve) => setTimeout(resolve, CLAIM_POLL_INTERVAL_MS));
      continue;
    }
    await handlePurchaseRequest(request, { baseUrl, config, agentAccount });
  }
  console.log('Worker stopped.');
}

const isMainModule = process.argv[1] ? import.meta.url === `file://${process.argv[1]}` : false;
if (isMainModule) {
  main().catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  });
}
