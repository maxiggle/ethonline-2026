import { Module } from '@nestjs/common';
import { RiskAnalysisService } from './risk-analysis.service';
import { PoliciesModule } from '../policies/policies.module';

@Module({
  imports: [PoliciesModule],
  providers: [RiskAnalysisService],
  exports: [RiskAnalysisService],
})
export class GuardianModule {}
