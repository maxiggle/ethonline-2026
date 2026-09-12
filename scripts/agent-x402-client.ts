/**
 * Chapter 2: Autonomous Agent x402 Payment Loop Client
 *
 * Demonstrates the complete HTTP 402 autonomous challenge, company invoice settlement,
 * and Bazaar discovery flow:
 * 1. x402 Bazaar Service Discovery -> Queries catalog for available endpoints
 * 2. Enterprise Account Invoices -> Queries outstanding company invoices
 * 3. Autonomous Bill Payment -> Dispatches payment for corporate bill with dynamic agent identity
 * 4. Guardian Tri-Verdict Policy Check -> Evaluates Safe mandate autonomous spending limit
 * 5. On-Chain Safe Transaction Execution & Settlement via Relayer
 * 6. Resource Access & Verification -> Verifies corporate receipt with X-Payment-Identifier
 */

async function main() {
  console.log('\n===============================================================');
  console.log('  CHAPTER 2: ENTERPRISE x402 BAZAAR & INVOICE CLIENT');
  console.log('===============================================================\n');

  const serverUrl = process.env.API_BASE_URL;
  if (!serverUrl) {
    console.error('[CONFIGURATION ERROR]: Missing required environment variable API_BASE_URL.');
    console.error('Please specify API_BASE_URL explicitly without fallbacks, for example:');
    console.error('  API_BASE_URL=https://chapter2-backend.onrender.com npx ts-node scripts/agent-x402-client.ts');
    console.error('  or');
    console.error('  API_BASE_URL=http://localhost:3000 npx ts-node scripts/agent-x402-client.ts\n');
    process.exit(1);
  }

  // Verify server reachability
  try {
    const healthCheck = await fetch(`${serverUrl}/actions`, { signal: AbortSignal.timeout(3000) });
    if (healthCheck.status >= 500) {
      throw new Error(`Server returned error status ${healthCheck.status}`);
    }
    console.log(`[NETWORK] Connected to live Chapter 2 backend at ${serverUrl}`);
  } catch (err) {
    throw new Error(`Could not reach Chapter 2 backend at ${serverUrl}. Ensure the service is running. Error: ${err}`);
  }

  // Dynamically resolve autonomous agent identity from live on-chain Safe mandate or env
  let agentAddress = process.env.AGENT_ADDRESS;
  if (!agentAddress) {
    console.log('[AGENT IDENTITY] Resolving authorized autonomous agent from active mandate...');
    const mandateRes = await fetch(`${serverUrl}/mandates/active`);
    if (!mandateRes.ok) {
      throw new Error(`Failed to query active mandate from ${serverUrl}/mandates/active: ${mandateRes.status}`);
    }
    const mandateData: any = await mandateRes.json();
    if (!mandateData.autonomousAgent) {
      throw new Error('No authorized autonomous agent configured in the active Safe mandate. Specify AGENT_ADDRESS in env.');
    }
    agentAddress = mandateData.autonomousAgent as string;
    console.log(`[AGENT IDENTITY] Dynamically bound to authorized agent from on-chain mandate: ${agentAddress}\n`);
  } else {
    console.log(`[AGENT IDENTITY] Using authorized agent from environment: ${agentAddress}\n`);
  }

  // -------------------------------------------------------------
  // STEP 1: Discover Services via x402 Bazaar Discovery Protocol
  // -------------------------------------------------------------
  console.log('-------------------------------------------------------------');
  console.log('[STEP 1] Querying x402 Bazaar Catalog: GET /discovery/resources');
  console.log('-------------------------------------------------------------');

  const bazaarRes = await fetch(`${serverUrl}/discovery/resources`);
  if (bazaarRes.ok) {
    const bazaarData: any = await bazaarRes.json();
    console.log(`[BAZAAR DISCOVERY] Protocol: ${bazaarData.protocol || 'x402-bazaar'} | Version: ${bazaarData.version || '0.1.0'}`);
    const items = (bazaarData.items as any[]) || [];
    console.log(`Discovered ${items.length} registered x402 payable endpoints:`);
    for (const item of items) {
      const accept = item.accepts?.[0] || {};
      console.log(`  ├─ ${item.extensions?.bazaar?.info?.serviceName || item.resource}`);
      console.log(`  │  Endpoint: ${item.resource} | Cost: ${Number(accept.amount || 0) / 1e6} USDC | PayTo: ${accept.payTo}`);
      console.log(`  │  Payment-Identifier: ${accept.extra?.paymentIdentifier || 'none'}`);
    }
    console.log('');
  } else {
    console.log(`[BAZAAR DISCOVERY] Note: GET /discovery/resources returned status ${bazaarRes.status}`);
  }

  // -------------------------------------------------------------
  // STEP 1B: Search Bazaar Services (e.g. "weather APIs")
  // -------------------------------------------------------------
  console.log('-------------------------------------------------------------');
  console.log('[STEP 1B] Searching Bazaar Catalog: GET /discovery/search?query=weather%20APIs&type=http');
  console.log('-------------------------------------------------------------');

  const searchRes = await fetch(`${serverUrl}/discovery/search?query=weather%20APIs&type=http`);
  if (searchRes.ok) {
    const searchResults: any = await searchRes.json();
    console.log(`Found ${searchResults.resources?.length || 0} services matching "weather APIs":`);
    for (const s of (searchResults.resources || [])) {
      const info = s.extensions?.bazaar?.info;
      console.log(`  ├─ ${info?.serviceName} ($${Number(s.accepts?.[0]?.amount || 0) / 1e6} USDC)`);
      console.log(`  │  Endpoint: ${s.resource} | Method: ${info?.input?.method || 'GET'}`);
      console.log(`  │  Default Params: ${JSON.stringify(info?.input?.queryParams || {})}`);
    }
    if (searchResults.pagination) {
      console.log(`  └─ Next page cursor: ${searchResults.pagination.cursor}`);
    }
    console.log('');

    // Demonstrate calling the selected service with x402 payment
    const selectedService = searchResults.resources?.[0];
    if (selectedService) {
      console.log('-------------------------------------------------------------');
      console.log(`[STEP 1C] Invoking Selected Service: POST /discovery/call (${selectedService.extensions?.bazaar?.info?.serviceName})`);
      console.log('-------------------------------------------------------------');
      const input = selectedService.extensions?.bazaar?.info?.input;
      const callRes = await fetch(`${serverUrl}/discovery/call`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resourceUrl: selectedService.resource,
          method: input?.method ?? 'GET',
          params: input?.queryParams ?? { city: 'San Francisco' },
          agentAddress,
        }),
      });

      if (callRes.ok) {
        const callResult: any = await callRes.json();
        console.log(`[CALL SUCCESS] ${callResult.serviceName}`);
        console.log(`  ├─ Cost       : $${callResult.costUsdc} USDC`);
        console.log(`  ├─ Tx Hash    : ${callResult.txHash}`);
        console.log(`  └─ Response   : ${JSON.stringify(callResult.data)}\n`);
      }
    }
  }

  // -------------------------------------------------------------
  // STEP 2: Query Enterprise Connected Accounts & Invoices
  // -------------------------------------------------------------
  console.log('-------------------------------------------------------------');
  console.log('[STEP 2] Fetching Enterprise Company Invoices: GET /vendor/bills');
  console.log('-------------------------------------------------------------');

  const billsRes = await fetch(`${serverUrl}/vendor/bills`);
  if (!billsRes.ok) {
    throw new Error(`Failed to fetch bills from ${serverUrl}/vendor/bills: ${billsRes.status} ${billsRes.statusText}`);
  }

  const bills: any[] = await billsRes.json();
  console.log(`Found ${bills.length} corporate bills for enterprise account:`);
  for (const b of bills) {
    console.log(`  ├─ [${b.status}] ${b.provider?.toUpperCase()} - ${b.invoiceNumber}: $${b.amountUsdc} USDC (${b.description})`);
    console.log(`  │  Payment Identifier: ${b.paymentIdentifier} | Due: ${b.dueDate}`);
  }
  console.log('');

  const targetBill = bills.find((b: any) => b.amountUsdc <= 50) || bills[0];
  let billTxHash: string | undefined;

  if (!targetBill) {
    console.log('[INFO] No pending corporate bills in queue (Clean zero-fallback state).');
  } else {
    const billId = targetBill.id;

    // -------------------------------------------------------------
    // STEP 3: Request x402 Challenge for Bill (${targetBill.invoiceNumber})
    // -------------------------------------------------------------
    console.log('-------------------------------------------------------------');
    console.log(`[STEP 3] Fetching x402 Challenge: GET /vendor/bills/${billId}`);
    console.log('-------------------------------------------------------------');

    const challengeRes = await fetch(`${serverUrl}/vendor/bills/${billId}`);
    console.log(`[HTTP RESPONSE] Status: ${challengeRes.status} ${challengeRes.statusText}`);

    const paymentAddress = challengeRes.headers.get('x-payment-address');
    const paymentAmount = challengeRes.headers.get('x-payment-amount');
    const paymentToken = challengeRes.headers.get('x-payment-token');
    const paymentIdentifier = challengeRes.headers.get('x-payment-identifier');

    console.log('\n[x402 CHALLENGE DETAILS]');
    console.log(`  ├─ Vendor Payment Address : ${paymentAddress}`);
    console.log(`  ├─ Required Token Amount  : ${paymentAmount} (${Number(paymentAmount || 0) / 1e6} USDC)`);
    console.log(`  ├─ Approved Token Address : ${paymentToken}`);
    console.log(`  └─ Payment Identifier     : ${paymentIdentifier}\n`);

    // -------------------------------------------------------------
    // STEP 4: Pay Corporate Bill via Chapter 2 Guardian Orchestrator
    // -------------------------------------------------------------
    console.log('-------------------------------------------------------------');
    console.log(`[STEP 4] Paying Company Bill: POST /vendor/bills/${billId}/pay`);
    console.log('-------------------------------------------------------------');

    const payRes = await fetch(`${serverUrl}/vendor/bills/${billId}/pay`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ agentAddress }),
    });

    if (!payRes.ok) {
      const err = await payRes.text();
      throw new Error(`Bill payment failed (${payRes.status}): ${err}`);
    }

    const payResult: any = await payRes.json();
    billTxHash = payResult.bill?.txHash || payResult.action?.txHash;

    console.log(`[GUARDIAN VERDICT] Action ID: ${payResult.action?.id}`);
    console.log(`  ├─ Guardian Decision      : ${payResult.decision?.decision}`);
    console.log(`  ├─ Risk Score             : ${payResult.decision?.riskScore} / 100`);
    console.log(`  ├─ Bill Status            : ${payResult.bill?.status}`);
    console.log(`  ├─ Verified On-Chain Hash : ${billTxHash || 'Pending Relayer'}`);
    if (billTxHash) {
      console.log(`  └─ Block Explorer Link    : https://sepolia.base.org/tx/${billTxHash}\n`);
    }
  }

  // -------------------------------------------------------------
  // STEP 5: Unlock Resource with Proof-of-Payment Header
  // -------------------------------------------------------------
  if (billTxHash) {
    console.log('-------------------------------------------------------------');
    console.log('[STEP 5] Verifying Resource Access: GET /vendor/compute');
    console.log('-------------------------------------------------------------');

    const unlockRes = await fetch(`${serverUrl}/vendor/compute`, {
      method: 'GET',
      headers: {
        'X-Payment-TxHash': billTxHash,
      },
    });

    console.log(`[HTTP RESPONSE] Status: ${unlockRes.status} ${unlockRes.statusText}`);

    if (unlockRes.ok) {
      const computeAccess: any = await unlockRes.json();
      console.log('\n===============================================================');
      console.log('  SUCCESS: CORPORATE BILL SETTLED & WORKLOAD UNLOCKED');
      console.log('===============================================================');
      console.log(`  ├─ Resource Status    : ${computeAccess.status}`);
      console.log(`  ├─ Granted Resource   : ${computeAccess.resource}`);
      console.log(`  ├─ Session Token      : ${computeAccess.sessionToken}`);
      console.log(`  ├─ Allocated Specs    : ${computeAccess.details?.specs}`);
      console.log(`  ├─ Settlement Tx      : ${computeAccess.txHash}`);
      console.log('===============================================================\n');
    }
  }
}

main().catch((err) => {
  console.error('\n[FATAL CLIENT ERROR]:', err);
  process.exit(1);
});
