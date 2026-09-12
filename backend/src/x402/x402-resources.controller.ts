import { Controller, Get, Query } from '@nestjs/common';
import { X402ResourcesService } from './x402-resources.service';

/**
 * x402 v2 resource handlers. No PrivyAuthGuard: the on-chain payment, verified by the
 * paymentMiddleware in main.ts before these handlers run, is the authorization.
 */
@Controller('x402')
export class X402ResourcesController {
  constructor(private readonly resourcesService: X402ResourcesService) {}

  @Get('weather')
  async getWeather(@Query('city') city: string | undefined): Promise<Record<string, any>> {
    return this.resourcesService.getWeather(city);
  }

  @Get('chain-report')
  async getChainReport(): Promise<Record<string, any>> {
    return this.resourcesService.getChainReport();
  }

  @Get('partner-feed')
  async getPartnerFeed(): Promise<Record<string, any>> {
    return this.resourcesService.getChainReport();
  }
}
