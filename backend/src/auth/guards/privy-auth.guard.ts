import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { PrivyAuthService } from '../privy-auth.service';

@Injectable()
export class PrivyAuthGuard implements CanActivate {
  constructor(private readonly authService: PrivyAuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers['authorization'];

    if (!authHeader) {
      throw new UnauthorizedException('Authorization header is required');
    }

    const [scheme, token] = authHeader.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Invalid authorization scheme. Bearer token required.');
    }

    try {
      const user = await this.authService.verifyAuthToken(token);
      // Attach authenticated user identity to request object
      request.user = user;
      return true;
    } catch (err: any) {
      throw new UnauthorizedException(err.message || 'Unauthorized');
    }
  }
}
