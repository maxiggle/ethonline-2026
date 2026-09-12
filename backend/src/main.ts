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
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const port = process.env.PORT || 3001;
  await app.listen(port);
}

bootstrap();
