import { createPublicClient, formatUnits, http, type Address } from 'viem';
import { baseSepolia } from 'viem/chains';

const BALANCE_OF_ABI = [
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const;

const USDC_DECIMALS = 6;

/** Reads a Base Sepolia USDC balance and formats it as a human-readable USDC amount. */
export async function readUsdcBalance(
  usdcAddress: Address,
  account: Address,
  rpcUrl: string,
): Promise<{ atomicAmount: bigint; formatted: string }> {
  const publicClient = createPublicClient({ chain: baseSepolia, transport: http(rpcUrl) });
  const atomicAmount = (await publicClient.readContract({
    address: usdcAddress,
    abi: BALANCE_OF_ABI,
    functionName: 'balanceOf',
    args: [account],
  })) as bigint;

  return { atomicAmount, formatted: formatUnits(atomicAmount, USDC_DECIMALS) };
}
