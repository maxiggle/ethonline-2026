import { Controller, Get, Post, Query, Body, Req, UseGuards } from '@nestjs/common';
import { VendorService, BazaarResource } from './vendor.service';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { AgentsService } from '../agents/agents.service';
import { InvokeServiceDto } from './dto/invoke-service.dto';

@Controller('discovery')
export class DiscoveryController {
  constructor(
    private readonly vendorService: VendorService,
    private readonly agentsService: AgentsService,
  ) {}

  @Get('resources')
  listResources(
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ): {
    items: BazaarResource[];
    pagination: {
      limit: number;
      offset: number;
      total: number;
    };
  } {
    let items = this.vendorService.getBazaarCatalog();
    if (type) {
      items = items.filter((i) => i.type === type);
    }

    const offsetNum = offset ? parseInt(offset, 10) : 0;
    const limitNum = limit ? parseInt(limit, 10) : 20;
    const paginated = items.slice(offsetNum, offsetNum + limitNum);

    return {
      items: paginated,
      pagination: {
        limit: limitNum,
        offset: offsetNum,
        total: items.length,
      },
    };
  }

  @Get('search')
  searchResources(
    @Query('query') query?: string,
    @Query('type') type?: string,
  ): {
    resources: BazaarResource[];
    pagination: {
      cursor: string | null;
      total: number;
    };
    count: number;
  } {
    const results = this.vendorService.searchBazaar(query, type);
    return {
      resources: results,
      pagination: {
        cursor: null,
        total: results.length,
      },
      count: results.length,
    };
  }

  @Post('call')
  @UseGuards(PrivyAuthGuard)
  async callService(@Req() request: AuthenticatedRequest, @Body() dto: InvokeServiceDto) {
    await this.agentsService.assertAgentOwnership(request.user.id, dto.agentAddress);
    return await this.vendorService.invokeService(
      dto.resourceUrl,
      dto.method,
      dto.params,
      dto.agentAddress,
    );
  }
}
