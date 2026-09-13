import { Inject, Injectable } from '@nestjs/common';
import { WORLD_ID_CONFIG, WorldIdConfig } from './world-id.config';

export interface WorldIdVerifyClient {
  verifyProof(result: any): Promise<any>;
}

export const WORLD_ID_VERIFY_CLIENT = Symbol('WORLD_ID_VERIFY_CLIENT');

@Injectable()
export class WorldIdVerifyClientImpl implements WorldIdVerifyClient {
  constructor(@Inject(WORLD_ID_CONFIG) private readonly config: WorldIdConfig) {}

  async verifyProof(result: any): Promise<any> {
    if (!this.config.isWorldIdConfigured || !this.config.rpId) {
      throw new Error('World ID is not configured');
    }

    const endpoint = `https://developer.world.org/api/v4/verify/${this.config.rpId}`;
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(result),
    });

    const body = await response.json().catch(() => null);

    if (!response.ok) {
      const code = body?.code ?? 'unknown_error';
      const detail = body?.detail ?? `HTTP ${response.status} ${response.statusText}`;
      throw new Error(`World ID verification failed: [${code}] ${detail}`);
    }

    return body;
  }
}
