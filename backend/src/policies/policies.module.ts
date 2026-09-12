import { Module } from '@nestjs/common';
import { PolicyEngineService } from './policy-engine.service';
import { MandatesController } from './mandates.controller';
import { AgentsModule } from '../agents/agents.module';

@Module({
  imports: [AgentsModule],
  controllers: [MandatesController],
  providers: [PolicyEngineService],
  exports: [PolicyEngineService],
})
export class PoliciesModule {}
