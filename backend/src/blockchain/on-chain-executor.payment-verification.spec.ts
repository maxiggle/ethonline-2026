import { Interface, getAddress } from 'ethers';
import { OnChainExecutorService } from './on-chain-executor.service';

const ERC20_TRANSFER_EVENT_INTERFACE = new Interface([
  'event Transfer(address indexed from, address indexed to, uint256 value)',
]);

function encodeTransferLog(address: string, from: string, to: string, value: bigint) {
  const { data, topics } = ERC20_TRANSFER_EVENT_INTERFACE.encodeEventLog('Transfer', [
    from,
    to,
    value,
  ]);
  return { address: getAddress(address), topics, data };
}

describe('OnChainExecutorService.verifyTokenTransfer', () => {
  let service: OnChainExecutorService;

  const token = '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
  const recipient = '0x1111111111111111111111111111111111111111';
  const otherToken = '0x2222222222222222222222222222222222222222';
  const otherRecipient = '0x3333333333333333333333333333333333333333';
  const payer = '0x4444444444444444444444444444444444444444';
  const txHash = '0x' + '1'.repeat(64);

  beforeEach(() => {
    service = new OnChainExecutorService();
  });

  it('verifies a payment when the transfer meets the minimum amount', async () => {
    const receipt = {
      status: 1,
      logs: [encodeTransferLog(token, payer, recipient, 1_000_000n)],
    };
    jest.spyOn(service.provider, 'getTransactionReceipt').mockResolvedValue(receipt as any);

    const result = await service.verifyTokenTransfer(txHash, {
      token,
      recipient,
      minimumAmount: 1_000_000n,
    });

    expect(result).toEqual({ verified: true, transferredAmount: 1_000_000n });
  });

  it('rejects a transfer sent to the wrong recipient', async () => {
    const receipt = {
      status: 1,
      logs: [encodeTransferLog(token, payer, otherRecipient, 1_000_000n)],
    };
    jest.spyOn(service.provider, 'getTransactionReceipt').mockResolvedValue(receipt as any);

    const result = await service.verifyTokenTransfer(txHash, {
      token,
      recipient,
      minimumAmount: 1_000_000n,
    });

    expect(result.verified).toBe(false);
    expect((result as any).transferredAmount).toBe(0n);
  });

  it('rejects a transfer of the wrong token', async () => {
    const receipt = {
      status: 1,
      logs: [encodeTransferLog(otherToken, payer, recipient, 1_000_000n)],
    };
    jest.spyOn(service.provider, 'getTransactionReceipt').mockResolvedValue(receipt as any);

    const result = await service.verifyTokenTransfer(txHash, {
      token,
      recipient,
      minimumAmount: 1_000_000n,
    });

    expect(result.verified).toBe(false);
    expect((result as any).transferredAmount).toBe(0n);
  });

  it('rejects an underpayment below the minimum amount', async () => {
    const receipt = {
      status: 1,
      logs: [encodeTransferLog(token, payer, recipient, 500_000n)],
    };
    jest.spyOn(service.provider, 'getTransactionReceipt').mockResolvedValue(receipt as any);

    const result = await service.verifyTokenTransfer(txHash, {
      token,
      recipient,
      minimumAmount: 1_000_000n,
    });

    expect(result.verified).toBe(false);
    expect((result as any).transferredAmount).toBe(500_000n);
  });

  it('rejects a reverted receipt', async () => {
    const receipt = {
      status: 0,
      logs: [encodeTransferLog(token, payer, recipient, 1_000_000n)],
    };
    jest.spyOn(service.provider, 'getTransactionReceipt').mockResolvedValue(receipt as any);

    const result = await service.verifyTokenTransfer(txHash, {
      token,
      recipient,
      minimumAmount: 1_000_000n,
    });

    expect(result).toEqual({ verified: false, error: 'Transaction reverted on-chain' });
  });

  it('rejects a missing receipt', async () => {
    jest.spyOn(service.provider, 'getTransactionReceipt').mockResolvedValue(null);

    const result = await service.verifyTokenTransfer(txHash, {
      token,
      recipient,
      minimumAmount: 1_000_000n,
    });

    expect(result).toEqual({
      verified: false,
      error: 'Transaction receipt not found on-chain',
    });
  });
});
