import { Module, forwardRef } from '@nestjs/common';
import { VendorController } from './vendor.controller';
import { DiscoveryController } from './discovery.controller';
import { VendorService } from './vendor.service';
import { BlockchainModule } from '../blockchain/blockchain.module';
import { ActionsModule } from '../actions/actions.module';
import { AgentsModule } from '../agents/agents.module';
import { X402Module } from '../x402/x402.module';

@Module({
  imports: [BlockchainModule, ActionsModule, AgentsModule, forwardRef(() => X402Module)],
  controllers: [VendorController, DiscoveryController],
  providers: [VendorService],
  exports: [VendorService],
})
export class VendorModule {}
