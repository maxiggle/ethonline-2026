import { Module } from '@nestjs/common';
import { Eip712Service } from './eip712.service';

@Module({
  providers: [Eip712Service],
  exports: [Eip712Service],
})
export class CryptoModule {}
