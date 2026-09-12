import { loadAgentAccount } from './lib/agent-account.js';

async function main() {
  const account = await loadAgentAccount();
  console.log(account.address);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
