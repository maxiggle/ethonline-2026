export class TreasuryMandate {
  chainId: number;
  safeAddress: string;
  guardAddress: string;
  autonomousAgent: string;
  humanSigner: string;
  maxAutonomousAmount: bigint;
  dailyAutonomousLimit: bigint;
  approvedRecipients: string[];
  approvedTokens: string[];
}
