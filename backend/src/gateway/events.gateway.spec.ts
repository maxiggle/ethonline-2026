import { Test, TestingModule } from '@nestjs/testing';
import { EventsGateway } from './events.gateway';
import { TreasuryAction, TreasuryActionStatus } from '../domain/treasury-action.entity';
import { GuardianDecision, GuardianDecisionType } from '../domain/guardian-decision.entity';
import { Server, Socket } from 'socket.io';

describe('EventsGateway', () => {
  let gateway: EventsGateway;
  let mockServer: Partial<Server>;

  beforeEach(async () => {
    mockServer = {
      emit: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [EventsGateway],
    }).compile();

    gateway = module.get<EventsGateway>(EventsGateway);
    gateway.server = mockServer as Server;
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });

  it('should respond to ping', () => {
    const mockSocket = {} as Socket;
    const response = gateway.handlePing(mockSocket);
    expect(response).toEqual({ event: 'pong', data: 'ok' });
  });

  it('should join actions_channel on subscribe:actions', () => {
    const mockSocket = {
      join: jest.fn(),
    } as unknown as Socket;

    const response = gateway.handleSubscribeActions(mockSocket);
    expect(mockSocket.join).toHaveBeenCalledWith('actions_channel');
    expect(response).toEqual({ event: 'subscribed', status: 'actions_channel' });
  });

  const sanitize = (obj: any) => JSON.parse(JSON.stringify(obj));

  it('should emit action:proposed event', () => {
    const action: TreasuryAction = {
      id: 'act-123',
      target: '0x0000000000000000000000000000000000041c4e',
      value: '0',
      data: '0x',
      token: '0x0000000000000000000000000000000000041c4e',
      recipient: '0x0000000000000000000000000000000000041c4e',
      amount: '50000000',
      agentAddress: '0x1111111111111111111111111111111111111111',
      justification: 'Benign operational payment',
      status: TreasuryActionStatus.PENDING,
      nonce: 1,
      deadline: 1800000000,
      riskScore: 10,
      requiresHumanApproval: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    gateway.emitActionProposed(action);

    expect(mockServer.emit).toHaveBeenCalledWith(
      'action:proposed',
      expect.objectContaining({
        action: sanitize(action),
        timestamp: expect.any(String),
      }),
    );
  });

  it('should emit action:escalated event with typedData', () => {
    const action: TreasuryAction = {
      id: 'act-escalated',
      target: '0x0000000000000000000000000000000000041c4e',
      value: '0',
      data: '0x',
      token: '0x0000000000000000000000000000000000041c4e',
      recipient: '0x0000000000000000000000000000000000041c4e',
      amount: '150000000',
      agentAddress: '0x1111111111111111111111111111111111111111',
      justification: 'High value transfer',
      status: TreasuryActionStatus.PENDING,
      nonce: 2,
      deadline: 1800000000,
      riskScore: 75,
      requiresHumanApproval: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const decision: GuardianDecision = {
      actionId: 'act-escalated',
      decision: GuardianDecisionType.ESCALATE,
      riskScore: 75,
      reasons: ['Amount exceeds autonomous threshold'],
      deterministicPassed: false,
      requiresHumanApproval: true,
      evaluatedAt: new Date(),
    };

    gateway.emitActionEscalated({
      action,
      decision,
      typedData: { primaryType: 'TreasuryActionApproval' },
    });

    expect(mockServer.emit).toHaveBeenCalledWith(
      'action:escalated',
      expect.objectContaining({
        action: sanitize(action),
        decision: sanitize(decision),
        typedData: { primaryType: 'TreasuryActionApproval' },
        timestamp: expect.any(String),
      }),
    );
  });

  it('should emit action:approved event', () => {
    const action: TreasuryAction = {
      id: 'act-approved',
      target: '0x0000000000000000000000000000000000041c4e',
      value: '0',
      data: '0x',
      token: '0x0000000000000000000000000000000000041c4e',
      recipient: '0x0000000000000000000000000000000000041c4e',
      amount: '50000000',
      agentAddress: '0x1111111111111111111111111111111111111111',
      justification: 'Approved',
      status: TreasuryActionStatus.APPROVED,
      nonce: 3,
      deadline: 1800000000,
      riskScore: 10,
      requiresHumanApproval: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    gateway.emitActionApproved({ action, safeTxData: '0x1234' });

    expect(mockServer.emit).toHaveBeenCalledWith(
      'action:approved',
      expect.objectContaining({
        action: sanitize(action),
        safeTxData: '0x1234',
        timestamp: expect.any(String),
      }),
    );
  });

  it('should emit action:rejected event', () => {
    const action: TreasuryAction = {
      id: 'act-rejected',
      target: '0x0000000000000000000000000000000000041c4e',
      value: '0',
      data: '0x',
      token: '0x0000000000000000000000000000000000041c4e',
      recipient: '0x0000000000000000000000000000000000041c4e',
      amount: '50000000',
      agentAddress: '0x1111111111111111111111111111111111111111',
      justification: 'Rejected',
      status: TreasuryActionStatus.REJECTED,
      nonce: 4,
      deadline: 1800000000,
      riskScore: 10,
      requiresHumanApproval: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    gateway.emitActionRejected({ action, reason: 'Operator rejected' });

    expect(mockServer.emit).toHaveBeenCalledWith(
      'action:rejected',
      expect.objectContaining({
        action: sanitize(action),
        reason: 'Operator rejected',
        timestamp: expect.any(String),
      }),
    );
  });

  it('should emit action:blocked event', () => {
    const action: TreasuryAction = {
      id: 'act-blocked',
      target: '0x0000000000000000000000000000000000041c4e',
      value: '0',
      data: '0x',
      token: '0x0000000000000000000000000000000000041c4e',
      recipient: '0x0000000000000000000000000000000000041c4e',
      amount: '50000000',
      agentAddress: '0x1111111111111111111111111111111111111111',
      justification: 'Blocked',
      status: TreasuryActionStatus.REJECTED,
      nonce: 5,
      deadline: 1800000000,
      riskScore: 100,
      requiresHumanApproval: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const decision: GuardianDecision = {
      actionId: 'act-blocked',
      decision: GuardianDecisionType.BLOCK,
      riskScore: 100,
      reasons: ['Unapproved recipient'],
      deterministicPassed: false,
      requiresHumanApproval: false,
      evaluatedAt: new Date(),
    };

    gateway.emitActionBlocked({ action, decision });

    expect(mockServer.emit).toHaveBeenCalledWith(
      'action:blocked',
      expect.objectContaining({
        action: sanitize(action),
        decision: sanitize(decision),
        timestamp: expect.any(String),
      }),
    );
  });
});
