export interface PrivyUserIdentity {
  id: string; // Privy DID: did:privy:...
  email?: string;
  name?: string;
  avatarUrl?: string;
  walletAddress?: string; // Privy Non-Custodial Embedded EVM Wallet address
}
