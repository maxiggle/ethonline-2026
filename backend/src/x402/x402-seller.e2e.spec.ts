import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { paymentMiddleware, x402ResourceServer } from '@x402/express';
import { ExactEvmScheme } from '@x402/evm/exact/server';
import { FacilitatorClient } from '@x402/core/server';
import { X402Module } from './x402.module';
import { loadX402Config } from './x402.config';
import { buildX402Routes } from './x402.routes';

/**
 * A fake facilitator that never reaches the network: getSupported() answers what
 * ExactEvmScheme needs to build the 402 challenge; verify/settle are unused here
 * because this suite only exercises the unpaid challenge path.
 */
class FakeFacilitatorClient implements FacilitatorClient {
  async getSupported() {
    return {
      kinds: [{ x402Version: 2, scheme: 'exact', network: 'eip155:84532' as const }],
      extensions: [],
      signers: {},
    };
  }
  async verify(): Promise<any> {
    throw new Error('not used in this suite');
  }
  async settle(): Promise<any> {
    throw new Error('not used in this suite');
  }
}

describe('x402 v2 seller (unpaid challenge)', () => {
  let app: INestApplication;
  let baseUrl: string;

  beforeAll(async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [X402Module],
    }).compile();

    app = moduleRef.createNestApplication();

    const config = loadX402Config();
    const resourceServer = new x402ResourceServer(new FakeFacilitatorClient()).register(
      config.network,
      new ExactEvmScheme(),
    );
    app.use(paymentMiddleware(buildX402Routes(config), resourceServer));

    await app.init();
    await app.listen(0);
    const address = app.getHttpServer().address();
    baseUrl = `http://127.0.0.1:${address.port}`;
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 402 with a decodable PAYMENT-REQUIRED header for Base Sepolia USDC', async () => {
    const response = await fetch(`${baseUrl}/x402/weather?city=Lagos`);
    expect(response.status).toBe(402);

    const encoded = response.headers.get('payment-required');
    expect(encoded).toBeTruthy();

    const decoded = JSON.parse(Buffer.from(encoded!, 'base64').toString('utf-8'));
    expect(decoded.accepts).toBeInstanceOf(Array);
    expect(decoded.accepts.length).toBeGreaterThan(0);

    const accept = decoded.accepts[0];
    expect(accept.network).toBe('eip155:84532');
    expect(accept.asset.toLowerCase()).toBe('0x036cbd53842c5426634e7929541ec2318f3dcf7e');
    expect(accept.payTo.toLowerCase()).toBe(loadX402Config().payToAddress.toLowerCase());
  });
});
