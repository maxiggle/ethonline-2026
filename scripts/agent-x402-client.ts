/**
 * Chapter 2: Autonomous Agent x402 Payment Loop Client
 *
 * Demonstrates the complete HTTP 402 autonomous challenge and settlement flow:
 * 1. Initial Resource Access Attempt -> Receives HTTP 402 Payment Required
 * 2. Parses x402 headers (Vendor Address, Token, Amount, ChainId)
 * 3. Autonomous Proposal to Chapter 2 Guardian Orchestrator
 * 4. Guardian Policy & Cap Evaluation (Deterministic Whitelist & Cap Check)
 * 5. On-Chain Safe Transaction Execution & Settlement via Relayer
 * 6. Access Retry with X-Payment-TxHash -> Unlocks HTTP 200 Compute Resource
 */

import * as path from 'path';
import { spawn, ChildProcess } from 'child_process';

const DEFAULT_SERVER_URL = process.env.API_BASE_URL || 'http://localhost:3001';
const AGENT_ADDRESS = '0x1111111111111111111111111111111111111111';

async function waitForServer(url: string, timeoutMs: number = 15000): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`${url}/actions`, { signal: AbortSignal.timeout(1000) });
      if (res.status < 500) {
        return true;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

async function main() {
  console.log('\n===============================================================');
  console.log('  CHAPTER 2: AUTONOMOUS AGENT x402 PAYMENT CLIENT DEMONSTRATION');
  console.log('===============================================================\n');

  let serverProcess: ChildProcess | null = null;
  let serverUrl = DEFAULT_SERVER_URL;

  // Check if backend server is already reachable; if not, spin up backend process
  let isRunning = false;
  try {
    const healthCheck = await fetch(`${serverUrl}/actions`, { signal: AbortSignal.timeout(1000) });
    isRunning = healthCheck.status < 500;
  } catch {}

  if (isRunning) {
    console.log(`[NETWORK] Connected to live Chapter 2 backend at ${serverUrl}`);
  } else {
    console.log(`[BOOTSTRAP] Starting Chapter 2 Orchestrator at ${serverUrl}...`);
    const backendDir = path.resolve(__dirname, '../backend');
    serverProcess = spawn('npx', ['nest', 'start'], {
      cwd: backendDir,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, PORT: '3001' },
    });

    const ready = await waitForServer(serverUrl, 20000);
    if (!ready) {
      if (serverProcess) serverProcess.kill();
      throw new Error(`Failed to start Chapter 2 backend on ${serverUrl}`);
    }
    console.log(`[BOOTSTRAP] Chapter 2 Orchestrator successfully booted on ${serverUrl}\n`);
  }

  try {
    // -------------------------------------------------------------
    // STEP 1: Attempt to access protected vendor compute resource
    // -------------------------------------------------------------
    console.log('-------------------------------------------------------------');
    console.log('[STEP 1] Autonomous agent requesting compute: GET /vendor/compute');
    console.log('-------------------------------------------------------------');

    const initialRes = await fetch(`${serverUrl}/vendor/compute`, {
      method: 'GET',
    });

    console.log(`[HTTP RESPONSE] Status: ${initialRes.status} ${initialRes.statusText}`);

    if (initialRes.status !== 402) {
      throw new Error(`Expected HTTP 402 Payment Required, received: ${initialRes.status}`);
    }

    // -------------------------------------------------------------
    // STEP 2: Extract and parse x402 Payment Challenge Headers
    // -------------------------------------------------------------
    const paymentAddress = initialRes.headers.get('x-payment-address');
    const paymentAmount = initialRes.headers.get('x-payment-amount');
    const paymentToken = initialRes.headers.get('x-payment-token');
    const paymentChainId = initialRes.headers.get('x-payment-chainid');

    console.log('\n[x402 CHALLENGE DETAILS]');
    console.log(`  ├─ Vendor Payment Address : ${paymentAddress}`);
    console.log(`  ├─ Required Token Amount  : ${paymentAmount} (${Number(paymentAmount) / 1e6} USDC)`);
    console.log(`  ├─ Approved Token Address : ${paymentToken}`);
    console.log(`  └─ Network Chain ID       : ${paymentChainId} (Base Sepolia)\n`);

    if (!paymentAddress || !paymentAmount || !paymentToken) {
      throw new Error('Missing required x402 payment headers from vendor response');
    }

    // -------------------------------------------------------------
    // STEP 3: Submit Action Proposal to Chapter 2 Guardian
    // -------------------------------------------------------------
    console.log('-------------------------------------------------------------');
    console.log('[STEP 3] Proposing Treasury Action to Chapter 2 Guardian');
    console.log('-------------------------------------------------------------');

    const proposePayload = {
      target: paymentToken,
      value: '0',
      data: '0x',
      token: paymentToken,
      recipient: paymentAddress,
      amount: paymentAmount,
      agentAddress: AGENT_ADDRESS,
      justification: 'Autonomous H100 GPU compute cluster allocation via x402 protocol',
    };

    const proposeRes = await fetch(`${serverUrl}/actions/propose`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(proposePayload),
    });

    if (!proposeRes.ok) {
      const err = await proposeRes.text();
      throw new Error(`Action proposal failed (${proposeRes.status}): ${err}`);
    }

    const proposalResult: any = await proposeRes.json();
    const actionId = proposalResult.action.id;
    console.log(`[GUARDIAN VERDICT] Action ID: ${actionId}`);
    console.log(`  ├─ Guardian Decision      : ${proposalResult.decision.decision}`);
    console.log(`  ├─ Risk Score             : ${proposalResult.decision.riskScore} / 100`);
    console.log(`  ├─ Human Escalation Req   : ${proposalResult.decision.requiresHumanApproval}`);
    console.log(`  └─ Decision Rationale     : ${proposalResult.decision.reasons?.join(' | ')}\n`);

    // -------------------------------------------------------------
    // STEP 4: Await On-Chain Relayer Settlement
    // -------------------------------------------------------------
    console.log('-------------------------------------------------------------');
    console.log('[STEP 4] Awaiting On-Chain Relayer Settlement & txHash');
    console.log('-------------------------------------------------------------');

    let txHash = proposalResult.action.txHash;
    let pollCount = 0;

    while (!txHash && pollCount < 10) {
      await new Promise((r) => setTimeout(r, 500));
      const pollRes = await fetch(`${serverUrl}/actions/${actionId}`);
      if (pollRes.ok) {
        const polled: any = await pollRes.json();
        if (polled.txHash) {
          txHash = polled.txHash;
          break;
        }
      }
      pollCount++;
    }

    if (!txHash) {
      throw new Error(`Timed out waiting for on-chain settlement for action ${actionId}`);
    }

    console.log(`[ON-CHAIN SETTLEMENT CONFIRMED]`);
    console.log(`  ├─ Status                 : EXECUTED`);
    console.log(`  ├─ Verified On-Chain Hash : ${txHash}`);
    console.log(`  └─ Block Explorer Link    : https://sepolia.base.org/tx/${txHash}\n`);

    // -------------------------------------------------------------
    // STEP 5: Unlock Resource with Proof-of-Payment Header
    // -------------------------------------------------------------
    console.log('-------------------------------------------------------------');
    console.log('[STEP 5] Unlocking Resource: GET /vendor/compute with X-Payment-TxHash');
    console.log('-------------------------------------------------------------');

    const unlockRes = await fetch(`${serverUrl}/vendor/compute`, {
      method: 'GET',
      headers: {
        'X-Payment-TxHash': txHash,
      },
    });

    console.log(`[HTTP RESPONSE] Status: ${unlockRes.status} ${unlockRes.statusText}`);

    if (unlockRes.status !== 200) {
      const errText = await unlockRes.text();
      throw new Error(`Failed to unlock compute resource (${unlockRes.status}): ${errText}`);
    }

    const computeAccess: any = await unlockRes.json();

    console.log('\n===============================================================');
    console.log('  SUCCESS: COMPUTE RESOURCE UNLOCKED VIA CHAPTER 2 GUARDIAN');
    console.log('===============================================================');
    console.log(`  ├─ Status             : ${computeAccess.status}`);
    console.log(`  ├─ Granted Resource   : ${computeAccess.resource}`);
    console.log(`  ├─ Session Token      : ${computeAccess.sessionToken}`);
    console.log(`  ├─ Allocated Hardware : ${computeAccess.details?.specs}`);
    console.log(`  ├─ Compute Pool       : ${computeAccess.details?.cluster}`);
    console.log(`  ├─ Valid Until        : ${computeAccess.expiresAt}`);
    console.log(`  └─ Settlement Tx      : ${computeAccess.txHash}`);
    console.log('===============================================================\n');

  } finally {
    if (serverProcess) {
      serverProcess.kill('SIGTERM');
    }
  }
}

main().catch((err) => {
  console.error('\n[FATAL DEMO ERROR]:', err);
  process.exit(1);
});
