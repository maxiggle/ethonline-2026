import { Module } from '@nestjs/common';
import { WorldSelfieService } from './world-selfie.service';
import { WorldController } from './world.controller';

@Module({
  controllers: [WorldController],
  providers: [WorldSelfieService],
  exports: [WorldSelfieService],
})
export class WorldModule {}
