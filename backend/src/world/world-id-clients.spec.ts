import { WorldIdRequestClientImpl } from './world-id-request.client';
import { WorldIdVerifyClientImpl } from './world-id-verify.client';
import { WorldIdConfig } from './world-id.config';

describe('WorldId Clients', () => {
  const configuredConfig: WorldIdConfig = {
    isWorldIdRequired: true,
    isWorldIdConfigured: true,
    appId: 'app_staging_123',
    rpId: 'rp_123456789abcdef0',
    signingKeyHex: '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff',
    action: 'chapter2-ledger-approver',
    environment: 'staging',
  };

  const unconfiguredConfig: WorldIdConfig = {
    isWorldIdRequired: false,
    isWorldIdConfigured: false,
  };

  describe('WorldIdRequestClientImpl', () => {
    it('throws when World ID is not configured', async () => {
      const client = new WorldIdRequestClientImpl(unconfiguredConfig);
      await expect(client.createOrbRequest('0x123')).rejects.toThrow('World ID is not configured');
    });

    it('creates an orb request when configured', async () => {
      const idkitCore = require('@worldcoin/idkit-core');
      const mockReq = {
        requestId: 'req_123',
        connectorURI: 'https://staging.world.org/verify?t=123',
        pollOnce: jest.fn().mockResolvedValue({ type: 'waiting_for_connection' }),
      };
      const presetSpy = jest.fn().mockResolvedValue(mockReq);
      const requestSpy = jest.spyOn(idkitCore.IDKit, 'request').mockReturnValue({
        preset: presetSpy,
      } as any);

      const client = new WorldIdRequestClientImpl(configuredConfig);
      const res = await client.createOrbRequest('0x1111111111111111111111111111111111111111');
      expect(requestSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          app_id: 'app_staging_123',
          action: 'chapter2-ledger-approver',
          allow_legacy_proofs: true,
          environment: 'staging',
        }),
      );
      expect(res.requestId).toBe('req_123');
      expect(res.connectorUrl).toBe('https://staging.world.org/verify?t=123');
      expect(typeof res.pollOnce).toBe('function');
      const pollRes = await res.pollOnce();
      expect(pollRes.type).toBe('waiting_for_connection');

      requestSpy.mockRestore();
    });
  });

  describe('WorldIdVerifyClientImpl', () => {
    const originalFetch = globalThis.fetch;

    afterEach(() => {
      globalThis.fetch = originalFetch;
    });

    it('throws when World ID is not configured', async () => {
      const client = new WorldIdVerifyClientImpl(unconfiguredConfig);
      await expect(client.verifyProof({})).rejects.toThrow('World ID is not configured');
    });

    it('posts to the correct endpoint and returns parsed json on 200', async () => {
      const mockResult = { success: true, results: [{ identifier: 'orb', success: true }] };
      globalThis.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResult,
      } as Response);

      const client = new WorldIdVerifyClientImpl(configuredConfig);
      const res = await client.verifyProof({ test: 123 });

      expect(globalThis.fetch).toHaveBeenCalledWith(
        'https://developer.world.org/api/v4/verify/rp_123456789abcdef0',
        expect.objectContaining({
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ test: 123 }),
        }),
      );
      expect(res).toEqual(mockResult);
    });

    it('throws error with code and detail on non-200 response', async () => {
      globalThis.fetch = jest.fn().mockResolvedValue({
        ok: false,
        status: 400,
        statusText: 'Bad Request',
        json: async () => ({ code: 'invalid_proof', detail: 'Proof could not be verified' }),
      } as Response);

      const client = new WorldIdVerifyClientImpl(configuredConfig);
      await expect(client.verifyProof({ test: 123 })).rejects.toThrow(
        'World ID verification failed: [invalid_proof] Proof could not be verified',
      );
    });
  });
});
