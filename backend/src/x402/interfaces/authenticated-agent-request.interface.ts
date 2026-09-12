import { Request } from 'express';
import { RawBodyRequest } from '@nestjs/common';
import { AgentEntity } from '../../agents/interfaces/agent.interface';

export interface AuthenticatedAgentRequest extends RawBodyRequest<Request> {
  agent: AgentEntity;
}
