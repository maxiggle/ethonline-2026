import * as fs from 'fs';
import * as path from 'path';
import { DatabaseService } from './database.service';
import { ActionStoreService } from '../actions/action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { WorldSelfieService } from '../world/world-selfie.service';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { WorldIdSelfieProof } from '../world/interfaces/world-selfie.interface';
import { DEFAULT_WORLD_ACTION } from '../world/world.constants';

describe('Persistence Across Restarts (0 Data Loss)', () => {
  const testDbFile = path.resolve(__dirname, '../../../data/test-restart.sqlite');

  beforeEach(() => {
    if (fs.existsSync(testDbFile)) {
      fs.unlinkSync(testDbFile);
    }
  });

  afterEach(() => {
    if (fs.existsSync(testDbFile)) {
      fs.unlinkSync(testDbFile);
    }
  });

  it('should persist actions, mandates, daily budget, and human bindings across backend restart', async () => {
    // === SESSION 1: Server running ===
    const db1 = new DatabaseService();
    await db1.initialize(testDbFile);

    const actionStore1 = new ActionStoreService(db1);
    const policyEngine1 = new PolicyEngineService(db1);
    const worldSelfie1 = new WorldSelfieService(db1);

    // 1. Create and execute action
    const dto: ProposeActionDto = {
      target: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      value: '0',
      data: '0x',
      token: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      recipient: '0x0000000000000000000000000000000000041c4e',
      amount: '40000000',
      agentAddress: '0x1111111111111111111111111111111111111111',
      justification: 'Compute session payment',
    };
    const action1 = actionStore1.createAction(dto, 'act-persistent-001');
    actionStore1.updateStatus(action1.id, TreasuryActionStatus.EXECUTED, {
      txHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    });

    // 2. Record daily spend & update mandate
    const nowSec = 1773000000;
    policyEngine1.recordAutonomousSpend('40000000', nowSec);
    policyEngine1.updateMandate({ maxAutonomousAmount: BigInt('120000000') });

    // 3. Bind human signer
    const signer = '0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7';
    const proof: WorldIdSelfieProof = {
      merkle_root: '0xroot',
      nullifier_hash: '0xnullifier_persisted_test',
      proof: '0xproof',
      credential_type: 'selfie',
      action: DEFAULT_WORLD_ACTION,
    };
    await worldSelfie1.bindHumanSigner(signer, proof);

    // === SIMULATE CRASH / RESTART: Close DB1 ===
    await db1.close();

    // === SESSION 2: Server restarts, connects to testDbFile ===
    const db2 = new DatabaseService();
    await db2.initialize(testDbFile);

    const actionStore2 = new ActionStoreService(db2);
    const policyEngine2 = new PolicyEngineService(db2);
    const worldSelfie2 = new WorldSelfieService(db2);

    // 1. Verify action preserved
    const retrievedAction = actionStore2.getAction('act-persistent-001');
    expect(retrievedAction).toBeDefined();
    expect(retrievedAction?.status).toBe(TreasuryActionStatus.EXECUTED);
    expect(retrievedAction?.txHash).toBe(
      '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    );
    expect(retrievedAction?.amount).toBe('40000000');

    // 2. Verify mandate and daily spend preserved
    expect(policyEngine2.getMandate().maxAutonomousAmount).toBe(BigInt('120000000'));
    expect(policyEngine2.getDailySpent(nowSec)).toBe(BigInt('40000000'));

    // 3. Verify human binding preserved
    const isVerified = await worldSelfie2.isHumanSignerVerified(signer);
    expect(isVerified).toBe(true);
    const binding = await worldSelfie2.getHumanBinding(signer);
    expect(binding?.nullifierHash).toBe('0xnullifier_persisted_test');

    await db2.close();
  });
});
