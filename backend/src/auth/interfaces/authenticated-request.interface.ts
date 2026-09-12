import { Request } from 'express';
import { PrivyUserIdentity } from './privy-user.interface';

export interface AuthenticatedRequest extends Request {
  user: PrivyUserIdentity;
}
