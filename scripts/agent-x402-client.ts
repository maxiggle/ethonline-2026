/**
 * Chapter 2: Guardian-gated x402 v2 agent demo client.
 *
 * An autonomous agent discovers paid x402 resources on Base Sepolia and asks the Chapter 2
 * Guardian before ever signing a payment:
 *   - ALLOW      -> paid by the agent's own Key Ring-protected wallet.
 *   - ESCALATE   -> paid by a signature collected on the human's Ledger via the web approval
 *                   console; this client only posts the typed data and polls for the result.
 *   - BLOCK      -> refused outright; no payment signature is ever created.
 * Every settlement is a real Base Sepolia USDC transfer, verified on-chain by the backend before
 * the corresponding `TreasuryAction` is marked `EXECUTED`.
 */
import { getAddress, type Address } from 'viem';

import { loadAgentAccount } from './lib/agent-account.js';
import { createLedgerRemoteSigner } from './lib/ledger-remote-signer.js';
import { readUsdcBalance } from './lib/usdc-balance.js';
import { payX402Resource, type PayResourceResult } from './lib/x402-payment-flow.js';

const BASE_SEPOLIA_RPC_URL = 'https://sepolia.base.org';

interface ApprovalConfig {
  approverAddress: string;
  network: string;
  usdcAddress: string;
}

type ScenarioName = 'allow' | 'escalate' | 'block';

interface Scenario {
  name: ScenarioName;
  title: string;
  resourcePath: string;
  justification: string;
}

const SCENARIOS: Scenario[] = [
  {
    name: 'allow',
    title: 'ALLOW: real-time weather (within the autonomous limit)',
    resourcePath: '/x402/weather?city=Lagos',
    justification: 'Fetch current weather for Lagos to brief the morning report.',
  },
  {
    name: 'escalate',
    title: 'ESCALATE: Base Sepolia chain report (above the autonomous limit)',
    resourcePath: '/x402/chain-report',
    justification: 'Fetch the latest Base Sepolia chain report for the treasury dashboard.',
  },
  {
    name: 'block',
    title: 'BLOCK: partner feed (unapproved payee)',
    resourcePath: '/x402/partner-feed',
    justification: 'Fetch the partner chain feed for a cross-check.',
  },
];

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}. See docs/tickets/README.md.`);
  }
  return value.trim();
}

function parseScenarioArg(argv: string[]): ScenarioName | 'all' {
  const flag = argv.find((arg) => arg.startsWith('--scenario='));
  const value = flag ? flag.slice('--scenario='.length) : 'all';
  if (value !== 'all' && value !== 'allow' && value !== 'escalate' && value !== 'block') {
    throw new Error(`Invalid --scenario value '${value}'; expected allow, escalate, block or all`);
  }
  return value;
}

async function printBalances(usdcAddress: Address, agentAddress: Address, ledgerAddress: Address): Promise<void> {
  const [agentBalance, ledgerBalance] = await Promise.all([
    readUsdcBalance(usdcAddress, agentAddress, BASE_SEPOLIA_RPC_URL),
    readUsdcBalance(usdcAddress, ledgerAddress, BASE_SEPOLIA_RPC_URL),
  ]);
  console.log(`  Agent USDC balance  (${agentAddress}): ${agentBalance.formatted} USDC`);
  console.log(`  Ledger USDC balance (${ledgerAddress}): ${ledgerBalance.formatted} USDC`);
}

async function runScenario(
  scenario: Scenario,
  baseUrl: string,
  agentAccount: Awaited<ReturnType<typeof loadAgentAccount>>,
  config: ApprovalConfig,
): Promise<void> {
  console.log(`\n=== ${scenario.title} ===`);
  console.log(`Resource: GET ${scenario.resourcePath}`);

  await printBalances(
    getAddress(config.usdcAddress),
    agentAccount.address,
    getAddress(config.approverAddress),
  );

  let result: PayResourceResult;
  try {
    result = await payX402Resource({
      baseUrl,
      network: config.network,
      usdcAddress: config.usdcAddress,
      resourcePath: scenario.resourcePath,
      justification: scenario.justification,
      agentAccount,
      agentEvmSigner: agentAccount,
      createLedgerSigner: (actionId) =>
        createLedgerRemoteSigner({
          approverAddress: getAddress(config.approverAddress),
          actionId,
          agentAccount,
          baseUrl,
        }),
      onWaitingForApproval: () => console.log('  Waiting for approval on Ledger console...'),
    });
  } catch (err) {
    console.error(`  Scenario '${scenario.name}' failed: ${err instanceof Error ? err.message : err}`);
    throw err;
  }

  if (result.kind === 'BLOCK') {
    console.log(`  BLOCKED (action ${result.actionId}, risk score ${result.riskScore}):`);
    for (const reason of result.reasons) {
      console.log(`    - ${reason}`);
    }
    return;
  }

  console.log(`  Guardian decision: ${result.decision} (action ${result.actionId})`);
  console.log(`  Settled transaction: ${result.transactionHash}`);
  console.log(`  Explorer: https://base-sepolia.blockscout.com/tx/${result.transactionHash}`);
  console.log(`  Response data: ${JSON.stringify(result.data)}`);
}

async function main(): Promise<void> {
  const baseUrl = requireEnv('API_BASE_URL').replace(/\/+$/, '');
  const keySource = requireEnv('AGENT_KEY_SOURCE');

  const scenarioArg = parseScenarioArg(process.argv.slice(2));
  const scenarios = scenarioArg === 'all' ? SCENARIOS : SCENARIOS.filter((s) => s.name === scenarioArg);

  console.log('Chapter 2: Guardian-gated x402 v2 agent demo');
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

  for (const scenario of scenarios) {
    await runScenario(scenario, baseUrl, agentAccount, config);
  }

  console.log('\nDemo complete.');
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
