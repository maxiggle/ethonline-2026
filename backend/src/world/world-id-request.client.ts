import { Inject, Injectable } from '@nestjs/common';
import { installIdkitWasmFileFetch } from './idkit-node-wasm-loader';
import { WORLD_ID_CONFIG, WorldIdConfig } from './world-id.config';

import type { IDKit as IDKitNamespace, orbLegacy as orbLegacyFn } from '@worldcoin/idkit-core' with { 'resolution-mode': 'import' };
import type { signRequest as signRequestFn } from '@worldcoin/idkit-server' with { 'resolution-mode': 'import' };

// eslint-disable-next-line @typescript-eslint/no-var-requires
const idkitCore = require('@worldcoin/idkit-core');
const IDKit: typeof IDKitNamespace = idkitCore.IDKit;
const orbLegacy: typeof orbLegacyFn = idkitCore.orbLegacy;
const signRequest: typeof signRequestFn = idkitCore.signRequest;

export interface WorldIdRequestResult {
  requestId: string;
  connectorUrl: string;
  pollOnce: () => Promise<any>;
}

export interface WorldIdRequestClient {
  createOrbRequest(signal: string): Promise<WorldIdRequestResult>;
}

export const WORLD_ID_REQUEST_CLIENT = Symbol('WORLD_ID_REQUEST_CLIENT');

@Injectable()
export class WorldIdRequestClientImpl implements WorldIdRequestClient {
  constructor(@Inject(WORLD_ID_CONFIG) private readonly config: WorldIdConfig) {}

  async createOrbRequest(signal: string): Promise<WorldIdRequestResult> {
    if (!this.config.isWorldIdConfigured) {
      throw new Error('World ID is not configured');
    }

    installIdkitWasmFileFetch();

    const { sig, nonce, createdAt, expiresAt } = signRequest({
      signingKeyHex: this.config.signingKeyHex!,
      action: this.config.action!,
      ttl: 900,
    });

    const rpContext = {
      rp_id: this.config.rpId!,
      nonce,
      created_at: createdAt,
      expires_at: expiresAt,
      signature: sig,
    };

    const builder = IDKit.request({
      app_id: this.config.appId!,
      action: this.config.action!,
      rp_context: rpContext,
      allow_legacy_proofs: true,
      environment: this.config.environment!,
    });

    const req = await builder.preset(orbLegacy({ signal }));

    return {
      requestId: req.requestId,
      connectorUrl: req.connectorURI,
      pollOnce: () => req.pollOnce(),
    };
  }
}
