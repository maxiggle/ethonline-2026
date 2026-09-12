import { Global, Module } from '@nestjs/common';
import { PrivyAuthService } from './privy-auth.service';
import { PrivyAuthGuard } from './guards/privy-auth.guard';
import { AuthController } from './auth.controller';
import { DatabaseModule } from '../database/database.module';

@Global()
@Module({
  imports: [DatabaseModule],
  controllers: [AuthController],
  providers: [PrivyAuthService, PrivyAuthGuard],
  exports: [PrivyAuthService, PrivyAuthGuard],
})
export class AuthModule {}
