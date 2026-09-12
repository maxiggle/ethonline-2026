import { Inject, Injectable, BadRequestException, NotFoundException, BadGatewayException } from '@nestjs/common';
import { JsonRpcProvider, Contract } from 'ethers';
import { X402_CONFIG } from './x402.constants';
import { X402Config } from './x402.config';

const ERC20_READ_ABI = [
  'function totalSupply() view returns (uint256)',
  'function decimals() view returns (uint8)',
];

interface OpenMeteoGeocodeResult {
  results?: Array<{
    name: string;
    latitude: number;
    longitude: number;
    country?: string;
    admin1?: string;
  }>;
}

interface OpenMeteoForecastResult {
  current?: {
    time: string;
    temperature_2m: number;
    relative_humidity_2m: number;
    wind_speed_10m: number;
    weather_code: number;
  };
}

@Injectable()
export class X402ResourcesService {
  private provider: JsonRpcProvider | null = null;

  constructor(@Inject(X402_CONFIG) private readonly config: X402Config) {}

  private getProvider(): JsonRpcProvider {
    if (!this.provider) {
      const rpcUrl = process.env.RPC_URL;
      if (!rpcUrl) {
        throw new Error('Missing required environment variable: RPC_URL');
      }
      this.provider = new JsonRpcProvider(rpcUrl);
    }
    return this.provider;
  }

  async getWeather(city: string | undefined): Promise<Record<string, any>> {
    if (!city || !city.trim()) {
      throw new BadRequestException("Query parameter 'city' is required");
    }

    const geocodeUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1`;
    let geocode: OpenMeteoGeocodeResult;
    try {
      const geocodeRes = await fetch(geocodeUrl);
      if (!geocodeRes.ok) {
        throw new Error(`Open-Meteo geocoding responded with ${geocodeRes.status}`);
      }
      geocode = (await geocodeRes.json()) as OpenMeteoGeocodeResult;
    } catch (err: any) {
      throw new BadGatewayException(`Failed to reach Open-Meteo geocoding: ${err.message}`);
    }

    const match = geocode.results?.[0];
    if (!match) {
      throw new NotFoundException(`No location found for city '${city}'`);
    }

    const forecastUrl =
      `https://api.open-meteo.com/v1/forecast?latitude=${match.latitude}&longitude=${match.longitude}` +
      `&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code`;
    let forecast: OpenMeteoForecastResult;
    try {
      const forecastRes = await fetch(forecastUrl);
      if (!forecastRes.ok) {
        throw new Error(`Open-Meteo forecast responded with ${forecastRes.status}`);
      }
      forecast = (await forecastRes.json()) as OpenMeteoForecastResult;
    } catch (err: any) {
      throw new BadGatewayException(`Failed to reach Open-Meteo forecast: ${err.message}`);
    }

    if (!forecast.current) {
      throw new BadGatewayException('Open-Meteo forecast response is missing current conditions');
    }

    return {
      city: match.name,
      country: match.country,
      region: match.admin1,
      latitude: match.latitude,
      longitude: match.longitude,
      temperatureC: forecast.current.temperature_2m,
      humidity: forecast.current.relative_humidity_2m,
      windSpeedKph: forecast.current.wind_speed_10m,
      weatherCode: forecast.current.weather_code,
      observedAt: forecast.current.time,
      source: 'open-meteo.com',
    };
  }

  async getChainReport(): Promise<Record<string, any>> {
    const provider = this.getProvider();
    const usdc = new Contract(this.config.usdcAddress, ERC20_READ_ABI, provider);

    const [block, feeData, totalSupply, decimals] = await Promise.all([
      provider.getBlock('latest'),
      provider.getFeeData(),
      usdc.totalSupply(),
      usdc.decimals(),
    ]);

    if (!block) {
      throw new BadGatewayException('Failed to read the latest Base Sepolia block');
    }

    return {
      network: 'eip155:84532',
      blockNumber: block.number,
      blockTimestamp: block.timestamp,
      gasPriceWei: feeData.gasPrice?.toString() ?? null,
      maxFeePerGasWei: feeData.maxFeePerGas?.toString() ?? null,
      maxPriorityFeePerGasWei: feeData.maxPriorityFeePerGas?.toString() ?? null,
      usdc: {
        address: this.config.usdcAddress,
        decimals: Number(decimals),
        totalSupply: totalSupply.toString(),
      },
      source: 'base-sepolia-rpc',
      observedAt: new Date().toISOString(),
    };
  }
}
