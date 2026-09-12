import { Module } from '@nestjs/common';
import { X402ResourcesController } from './x402-resources.controller';
import { X402ResourcesService } from './x402-resources.service';
import { X402PaymentsController } from './x402-payments.controller';
import { X402PaymentsService } from './x402-payments.service';
import { X402SpendingPolicyService } from './x402-spending-policy.service';
import { AgentSignatureGuard } from './guards/agent-signature.guard';
import { loadX402Config } from './x402.config';
import { X402_CONFIG } from './x402.constants';
import { ActionsModule } from '../actions/actions.module';
import { AgentsModule } from '../agents/agents.module';
import { GuardianModule } from '../guardian/guardian.module';
import { GatewayModule } from '../gateway/gateway.module';
import { BlockchainModule } from '../blockchain/blockchain.module';

@Module({
  imports: [ActionsModule, AgentsModule, GuardianModule, GatewayModule, BlockchainModule],
  controllers: [X402ResourcesController, X402PaymentsController],
  providers: [
    X402ResourcesService,
    X402PaymentsService,
    X402SpendingPolicyService,
    AgentSignatureGuard,
    { provide: X402_CONFIG, useFactory: loadX402Config },
  ],
  exports: [X402_CONFIG],
})
export class X402Module {}
