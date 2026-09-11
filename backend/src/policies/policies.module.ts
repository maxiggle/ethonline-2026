import { Module } from '@nestjs/common';
import { PolicyEngineService } from './policy-engine.service';
import { MandatesController } from './mandates.controller';

@Module({
  controllers: [MandatesController],
  providers: [PolicyEngineService],
  exports: [PolicyEngineService],
})
export class PoliciesModule {}
