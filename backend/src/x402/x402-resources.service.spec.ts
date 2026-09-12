import { BadGatewayException, BadRequestException, NotFoundException } from '@nestjs/common';
import { X402ResourcesService } from './x402-resources.service';
import { X402Config } from './x402.config';

describe('X402ResourcesService', () => {
  const config: X402Config = {
    network: 'eip155:84532',
    facilitatorUrl: 'https://x402.org/facilitator',
    usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    payToAddress: '0x4087a2be5527867612424fF2b0B821318D4Dc2fa',
    partnerPayToAddress: '0xbB55f3472773EAB736E5BCaC5FE6e6C5B30f5E35',
    publicBaseUrl: 'https://chapter2-backend.onrender.com',
  };

  let service: X402ResourcesService;
  let fetchMock: jest.Mock;

  beforeEach(() => {
    service = new X402ResourcesService(config);
    fetchMock = jest.fn();
    global.fetch = fetchMock as any;
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  const jsonResponse = (body: unknown, ok = true, status = 200) => ({
    ok,
    status,
    json: async () => body,
  });

  describe('getWeather', () => {
    it('rejects a missing city', async () => {
      await expect(service.getWeather(undefined)).rejects.toThrow(BadRequestException);
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('returns real telemetry for a geocoded city', async () => {
      fetchMock
        .mockResolvedValueOnce(
          jsonResponse({
            results: [{ name: 'Lagos', latitude: 6.4531, longitude: 3.3958, country: 'Nigeria' }],
          }),
        )
        .mockResolvedValueOnce(
          jsonResponse({
            current: {
              time: '2026-09-12T12:00',
              temperature_2m: 29.4,
              relative_humidity_2m: 77,
              wind_speed_10m: 11.2,
              weather_code: 2,
            },
          }),
        );

      const result = await service.getWeather('Lagos');

      expect(result.city).toBe('Lagos');
      expect(result.temperatureC).toBe(29.4);
      expect(result.source).toBe('open-meteo.com');
      expect(fetchMock).toHaveBeenCalledTimes(2);
    });

    it('throws 404 when geocoding finds nothing', async () => {
      fetchMock.mockResolvedValueOnce(jsonResponse({ results: [] }));

      await expect(service.getWeather('Nowhereville')).rejects.toThrow(NotFoundException);
    });

    it('throws 502 when the geocoding upstream fails', async () => {
      fetchMock.mockResolvedValueOnce(jsonResponse({}, false, 500));

      await expect(service.getWeather('Lagos')).rejects.toThrow(BadGatewayException);
    });

    it('throws 502 when the forecast upstream fails', async () => {
      fetchMock
        .mockResolvedValueOnce(
          jsonResponse({ results: [{ name: 'Lagos', latitude: 6.4531, longitude: 3.3958 }] }),
        )
        .mockResolvedValueOnce(jsonResponse({}, false, 503));

      await expect(service.getWeather('Lagos')).rejects.toThrow(BadGatewayException);
    });
  });

  describe('getChainReport', () => {
    it('reads block, fee data and USDC supply from a read-only provider', async () => {
      process.env.RPC_URL = 'https://sepolia.base.org';
      const mockBlock = { number: 12345, timestamp: 1_700_000_000 };
      const mockFeeData = {
        gasPrice: 1_000_000_000n,
        maxFeePerGas: 2_000_000_000n,
        maxPriorityFeePerGas: 100_000_000n,
      };

      jest.spyOn(require('ethers'), 'JsonRpcProvider').mockImplementation(function (this: any) {
        this.getBlock = jest.fn().mockResolvedValue(mockBlock);
        this.getFeeData = jest.fn().mockResolvedValue(mockFeeData);
      } as any);
      jest.spyOn(require('ethers'), 'Contract').mockImplementation(function (this: any) {
        this.totalSupply = jest.fn().mockResolvedValue(123_456_000_000n);
        this.decimals = jest.fn().mockResolvedValue(6);
      } as any);

      const result = await service.getChainReport();

      expect(result.blockNumber).toBe(12345);
      expect(result.usdc.decimals).toBe(6);
      expect(result.usdc.totalSupply).toBe('123456000000');
      expect(result.gasPriceWei).toBe('1000000000');
    });
  });
});
