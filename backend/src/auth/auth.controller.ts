import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { PrivyAuthService } from './privy-auth.service';
import { PrivyAuthGuard } from './guards/privy-auth.guard';
import { LoginDto } from './dto/login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: PrivyAuthService) {}

  /**
   * Client logs in with Privy auth token received after Google or Email authentication.
   * Backend verifies token, captures user profile and embedded wallet address, and syncs to database.
   */
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto) {
    const identity = await this.authService.verifyAuthToken(dto.authToken);
    const syncedUser = await this.authService.syncUser(identity);

    return {
      success: true,
      message: 'Authenticated successfully',
      user: syncedUser || identity,
    };
  }

  /**
   * Protected endpoint returning current authenticated user profile and embedded wallet address.
   */
  @Get('me')
  @UseGuards(PrivyAuthGuard)
  async getProfile(@Req() req: any) {
    const user = await this.authService.getUser(req.user.id);
    return {
      success: true,
      user: user || req.user,
    };
  }
}
