import { Module } from '@nestjs/common';
import { PoliciesModule } from './policies/policies.module';

@Module({
  imports: [PoliciesModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
