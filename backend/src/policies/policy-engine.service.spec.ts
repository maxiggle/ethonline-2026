import { PolicyEngineService } from './policy-engine.service';
import { GuardianDecisionType } from '../domain/guardian-decision.entity';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';

describe('PolicyEngineService', () => {
  let service: PolicyEngineService;

  const validRecipient = '0x0000000000000000000000000000000000041c4e';
  const invalidRecipient = '0x9999999999999999999999999999999999999999';
  const validToken = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
  const invalidToken = '0x8888888888888888888888888888888888888888';

  const createMockAction = (
    recipient: string,
    amount: string,
    token: string = validToken,
  ): TreasuryAction => ({
    id: 'act-test-01',
    target: token,
    value: '0',
    data: '0x',
    token,
    recipient,
    amount,
    agentAddress: '0x1111111111111111111111111111111111111111',
    justification: 'Automated infrastructure payment',
    status: TreasuryActionStatus.PENDING,
    nonce: 1,
    deadline: Math.floor(Date.now() / 1000) + 3600,
    riskScore: 10,
    requiresHumanApproval: false,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  beforeEach(() => {
    service = new PolicyEngineService();
  });

  it('should ALLOW autonomous action when within limit and recipient is whitelisted', () => {
    const action = createMockAction(validRecipient, '40000000');
    const result = service.evaluateDeterministicRules(action);

    expect(result.decision).toBe(GuardianDecisionType.ALLOW);
    expect(result.passed).toBe(true);
    expect(result.requiresHumanApproval).toBe(false);
  });

  it('should BLOCK action when recipient is not whitelisted', () => {
    const action = createMockAction(invalidRecipient, '40000000');
    const result = service.evaluateDeterministicRules(action);

    expect(result.decision).toBe(GuardianDecisionType.BLOCK);
    expect(result.passed).toBe(false);
    expect(result.reasons[0]).toContain('not on the approved whitelist');
  });

  it('should BLOCK action when token is not approved', () => {
    const action = createMockAction(validRecipient, '40000000', invalidToken);
    const result = service.evaluateDeterministicRules(action);

    expect(result.decision).toBe(GuardianDecisionType.BLOCK);
    expect(result.passed).toBe(false);
    expect(result.reasons[0]).toContain('not approved for treasury operations');
  });

  it('should ESCALATE action when amount exceeds single transaction cap', () => {
    const action = createMockAction(validRecipient, '850000000');
    const result = service.evaluateDeterministicRules(action);

    expect(result.decision).toBe(GuardianDecisionType.ESCALATE);
    expect(result.passed).toBe(false);
    expect(result.requiresHumanApproval).toBe(true);
    expect(result.reasons[0]).toContain('exceeds single autonomous limit');
  });

  it('should ESCALATE action when cumulative daily spend exceeds daily limit', () => {
    const fixedTimestamp = 1700000000;
    service.recordAutonomousSpend('450000000', fixedTimestamp);

    const action = createMockAction(validRecipient, '60000000');
    const result = service.evaluateDeterministicRules(action, fixedTimestamp);

    expect(result.decision).toBe(GuardianDecisionType.ESCALATE);
    expect(result.passed).toBe(false);
    expect(result.requiresHumanApproval).toBe(true);
    expect(result.reasons[0]).toContain('exceeds daily autonomous limit');
  });

  it('should correctly report remaining daily budget', () => {
    const fixedTimestamp = 1700000000;
    expect(service.getRemainingDailyBudget(fixedTimestamp)).toBe(BigInt('500000000'));

    service.recordAutonomousSpend('200000000', fixedTimestamp);
    expect(service.getRemainingDailyBudget(fixedTimestamp)).toBe(BigInt('300000000'));

    service.recordAutonomousSpend('300000000', fixedTimestamp);
    expect(service.getRemainingDailyBudget(fixedTimestamp)).toBe(BigInt('0'));
  });
});
