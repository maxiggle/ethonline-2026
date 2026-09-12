import * as dotenv from 'dotenv';
import * as fs from 'fs';

// Load local working directory .env
dotenv.config();

// Load Render Secret Files if mounted (/etc/secrets/.env or /etc/secrets/secrets.env)
for (const secretPath of ['/etc/secrets/.env', '/etc/secrets/secrets.env']) {
  if (fs.existsSync(secretPath)) {
    dotenv.config({ path: secretPath });
  }
}

import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { paymentMiddleware, x402ResourceServer } from '@x402/express';
import { HTTPFacilitatorClient } from '@x402/core/server';
import { ExactEvmScheme } from '@x402/evm/exact/server';
import { AppModule } from './app.module';
import { X402_CONFIG } from './x402/x402.constants';
import { X402Config } from './x402/x402.config';
import { buildX402Routes } from './x402/x402.routes';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.enableCors();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const x402Config = app.get<X402Config>(X402_CONFIG);
  const facilitatorClient = new HTTPFacilitatorClient({ url: x402Config.facilitatorUrl });
  const x402PaymentServer = new x402ResourceServer(facilitatorClient).register(
    x402Config.network,
    new ExactEvmScheme(),
  );
  app.use(paymentMiddleware(buildX402Routes(x402Config), x402PaymentServer));

  const port = process.env.PORT || 3001;
  await app.listen(port);
}

bootstrap();
