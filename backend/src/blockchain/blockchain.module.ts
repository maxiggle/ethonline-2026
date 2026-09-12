import { Module, Global } from '@nestjs/common';
import { OnChainExecutorService } from './on-chain-executor.service';
import { ActionsModule } from '../actions/actions.module';
import { PoliciesModule } from '../policies/policies.module';
import { CryptoModule } from '../crypto/crypto.module';
import { GatewayModule } from '../gateway/gateway.module';

@Global()
@Module({
  imports: [ActionsModule, PoliciesModule, CryptoModule, GatewayModule],
  providers: [OnChainExecutorService],
  exports: [OnChainExecutorService],
})
export class BlockchainModule {}
