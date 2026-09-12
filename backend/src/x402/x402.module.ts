import { Module } from '@nestjs/common';
import { X402ResourcesController } from './x402-resources.controller';
import { X402ResourcesService } from './x402-resources.service';
import { loadX402Config } from './x402.config';
import { X402_CONFIG } from './x402.constants';

@Module({
  controllers: [X402ResourcesController],
  providers: [
    X402ResourcesService,
    { provide: X402_CONFIG, useFactory: loadX402Config },
  ],
  exports: [X402_CONFIG],
})
export class X402Module {}
