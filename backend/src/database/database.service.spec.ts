import { Test, TestingModule } from '@nestjs/testing';
import { DatabaseService } from './database.service';

describe('DatabaseService', () => {
  let service: DatabaseService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [DatabaseService],
    }).compile();

    service = module.get<DatabaseService>(DatabaseService);
    await service.initialize(':memory:');
  });

  afterEach(async () => {
    await service.close();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should initialize tables and execute queries', async () => {
    await service.run(
      `INSERT INTO treasury_actions (id, target, value, data, token, recipient, amount, agent_address, justification, status, risk_score, requires_human_approval, nonce, deadline, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        'act-test-1',
        '0x0000000000000000000000000000000000041c4e',
        '0',
        '0x',
        '0x0000000000000000000000000000000000041c4e',
        '0x0000000000000000000000000000000000041c4e',
        '40000000',
        '0x1111111111111111111111111111111111111111',
        'Test action',
        'PENDING',
        10,
        0,
        1,
        1800000000,
        new Date().toISOString(),
        new Date().toISOString(),
      ],
    );

    const action = await service.getOne('SELECT * FROM treasury_actions WHERE id = ?', ['act-test-1']);
    expect(action).toBeDefined();
    expect(action.id).toBe('act-test-1');
    expect(action.amount).toBe('40000000');
    expect(action.status).toBe('PENDING');
  });

  it('should manage daily_spent_ledger correctly', async () => {
    const dayId = 20000;
    await service.run(
      `INSERT INTO daily_spent_ledger (day_id, cumulative_spent, updated_at) VALUES (?, ?, ?)`,
      [dayId, '50000000', new Date().toISOString()],
    );

    const ledger = await service.getOne('SELECT * FROM daily_spent_ledger WHERE day_id = ?', [dayId]);
    expect(ledger).toBeDefined();
    expect(ledger.cumulative_spent).toBe('50000000');
  });

  it('should manage human_bindings correctly', async () => {
    const signer = '0x1234567890123456789012345678901234567890';
    const nullifier = '0xnullifier123';
    await service.run(
      `INSERT INTO human_bindings (signer_address, nullifier_hash, bound_at, expires_at) VALUES (?, ?, ?, ?)`,
      [signer, nullifier, new Date().toISOString(), new Date(Date.now() + 100000).toISOString()],
    );

    const binding = await service.getOne('SELECT * FROM human_bindings WHERE signer_address = ?', [signer]);
    expect(binding).toBeDefined();
    expect(binding.nullifier_hash).toBe(nullifier);
  });

  it('should redeem an x402 payment receipt once and reject a replay', async () => {
    const txHash = `0x${[...Array(64)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`;

    const firstInsert = await service.run(
      `INSERT INTO x402_payment_receipts (tx_hash, resource, amount, redeemed_at) VALUES (?, ?, ?, ?) ON CONFLICT (tx_hash) DO NOTHING`,
      [txHash, 'vendor:compute', '1000000', new Date().toISOString()],
    );
    expect(firstInsert.changes).toBe(1);

    const replayInsert = await service.run(
      `INSERT INTO x402_payment_receipts (tx_hash, resource, amount, redeemed_at) VALUES (?, ?, ?, ?) ON CONFLICT (tx_hash) DO NOTHING`,
      [txHash, 'bill:some-other-bill', '2000000', new Date().toISOString()],
    );
    expect(replayInsert.changes).toBe(0);

    const receipt = await service.getOne('SELECT * FROM x402_payment_receipts WHERE tx_hash = ?', [txHash]);
    expect(receipt).toBeDefined();
    expect(receipt.resource).toBe('vendor:compute');
  });

  it('should store and sign an x402 escalation', async () => {
    const actionId = `act_test_${Date.now()}`;
    await service.run(
      `INSERT INTO x402_escalations (action_id, resource_url, typed_data, signature, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [actionId, 'https://example.com/x402/chain-report', '{"primaryType":"TransferWithAuthorization"}', null, 'AWAITING_SIGNATURE', new Date().toISOString(), new Date().toISOString()],
    );

    const created = await service.getOne('SELECT * FROM x402_escalations WHERE action_id = ?', [actionId]);
    expect(created).toBeDefined();
    expect(created.status).toBe('AWAITING_SIGNATURE');
    expect(created.signature).toBeNull();

    const updateResult = await service.run(
      `UPDATE x402_escalations SET status = ?, signature = ?, updated_at = ? WHERE action_id = ?`,
      ['SIGNED', '0xdeadbeef', new Date().toISOString(), actionId],
    );
    expect(updateResult.changes).toBe(1);

    const signed = await service.getOne('SELECT * FROM x402_escalations WHERE action_id = ?', [actionId]);
    expect(signed.status).toBe('SIGNED');
    expect(signed.signature).toBe('0xdeadbeef');
  });
});
