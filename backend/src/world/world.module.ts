import { Module } from '@nestjs/common';
import { WorldSelfieService } from './world-selfie.service';
import { WorldController } from './world.controller';
import { WorldIdApproverController } from './world-id-approver.controller';
import { WorldIdApproverService } from './world-id-approver.service';
import { WORLD_ID_CONFIG, loadWorldIdConfig } from './world-id.config';
import { WORLD_ID_REQUEST_CLIENT, WorldIdRequestClientImpl } from './world-id-request.client';
import { WORLD_ID_VERIFY_CLIENT, WorldIdVerifyClientImpl } from './world-id-verify.client';
import { loadX402Config } from '../x402/x402.config';
import { X402_CONFIG } from '../x402/x402.constants';

@Module({
  controllers: [WorldController, WorldIdApproverController],
  providers: [
    WorldSelfieService,
    WorldIdApproverService,
    { provide: WORLD_ID_CONFIG, useFactory: loadWorldIdConfig },
    { provide: X402_CONFIG, useFactory: loadX402Config },
    { provide: WORLD_ID_REQUEST_CLIENT, useClass: WorldIdRequestClientImpl },
    { provide: WORLD_ID_VERIFY_CLIENT, useClass: WorldIdVerifyClientImpl },
  ],
  exports: [WorldSelfieService, WorldIdApproverService],
})
export class WorldModule {}
