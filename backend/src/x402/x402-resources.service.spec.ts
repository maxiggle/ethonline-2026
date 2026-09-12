import { BadGatewayException, BadRequestException, NotFoundException } from '@nestjs/common';
import { X402ResourcesService } from './x402-resources.service';
import { loadX402Config } from './x402.config';

describe('X402ResourcesService', () => {
  const config = loadX402Config();

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
