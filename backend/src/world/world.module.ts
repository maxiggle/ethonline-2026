import { Module } from '@nestjs/common';
import { WorldSelfieService } from './world-selfie.service';

@Module({
  providers: [WorldSelfieService],
  exports: [WorldSelfieService],
})
export class WorldModule {}
