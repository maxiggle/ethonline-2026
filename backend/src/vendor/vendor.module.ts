import { Module } from '@nestjs/common';
import { VendorController } from './vendor.controller';
import { VendorService } from './vendor.service';
import { BlockchainModule } from '../blockchain/blockchain.module';
import { ActionsModule } from '../actions/actions.module';

@Module({
  imports: [BlockchainModule, ActionsModule],
  controllers: [VendorController],
  providers: [VendorService],
  exports: [VendorService],
})
export class VendorModule {}
