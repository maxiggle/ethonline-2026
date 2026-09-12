import { Controller, Get, Post, Query, Body, BadRequestException } from '@nestjs/common';
import { VendorService, BazaarResource } from './vendor.service';

@Controller('discovery')
export class DiscoveryController {
  constructor(private readonly vendorService: VendorService) {}

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
  async callService(
    @Body()
    dto: {
      resourceUrl: string;
      method?: string;
      params?: Record<string, any>;
      agentAddress?: string;
    },
  ) {
    if (!dto.resourceUrl) {
      throw new BadRequestException('resourceUrl is required');
    }
    return await this.vendorService.invokeService(
      dto.resourceUrl,
      dto.method,
      dto.params,
      dto.agentAddress,
    );
  }
}
