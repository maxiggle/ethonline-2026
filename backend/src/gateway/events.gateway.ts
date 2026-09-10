import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
} from '@nestjs/websockets';
import { Injectable, Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { TreasuryAction } from '../domain/treasury-action.entity';
import { GuardianDecision } from '../domain/guardian-decision.entity';

@Injectable()
@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class EventsGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(EventsGateway.name);

  afterInit(server: Server) {
    this.logger.log('EventsGateway initialized');
  }

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('ping')
  handlePing(client: Socket): { event: string; data: string } {
    return { event: 'pong', data: 'ok' };
  }

  @SubscribeMessage('subscribe:actions')
  handleSubscribeActions(client: Socket): { event: string; status: string } {
    client.join('actions_channel');
    return { event: 'subscribed', status: 'actions_channel' };
  }

  emitActionProposed(action: TreasuryAction): void {
    if (this.server) {
      this.server.emit('action:proposed', {
        action,
        timestamp: new Date().toISOString(),
      });
    }
  }

  emitActionEscalated(payload: {
    action: TreasuryAction;
    decision: GuardianDecision;
    typedData: any;
    prompt?: any;
  }): void {
    if (this.server) {
      this.server.emit('action:escalated', {
        ...payload,
        timestamp: new Date().toISOString(),
      });
    }
  }

  emitActionApproved(payload: {
    action: TreasuryAction;
    executionPayload?: any;
    safeTxData?: string;
  }): void {
    if (this.server) {
      this.server.emit('action:approved', {
        ...payload,
        timestamp: new Date().toISOString(),
      });
    }
  }

  emitActionRejected(payload: {
    action: TreasuryAction;
    reason?: string;
  }): void {
    if (this.server) {
      this.server.emit('action:rejected', {
        ...payload,
        timestamp: new Date().toISOString(),
      });
    }
  }

  emitActionBlocked(payload: {
    action: TreasuryAction;
    decision: GuardianDecision;
  }): void {
    if (this.server) {
      this.server.emit('action:blocked', {
        ...payload,
        timestamp: new Date().toISOString(),
      });
    }
  }
}
