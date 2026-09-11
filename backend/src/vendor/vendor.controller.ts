import {
  Controller,
  Get,
  Headers,
  Res,
  HttpException,
  HttpStatus,
  HttpCode,
} from '@nestjs/common';
import { Response } from 'express';
import { VendorService, ComputeResourceGrant } from './vendor.service';

@Controller('vendor')
export class VendorController {
  constructor(private readonly vendorService: VendorService) {}

  @Get('compute')
  async getComputeResource(
    @Headers('x-payment-txhash') paymentTxHash: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ComputeResourceGrant> {
    const reqs = this.vendorService.getPaymentRequirements();

    // If payment header is missing, trigger HTTP 402 Payment Required
    if (!paymentTxHash) {
      res.setHeader('X-Payment-Address', reqs.address);
      res.setHeader('X-Payment-Amount', reqs.amount);
      res.setHeader('X-Payment-Token', reqs.token);
      res.setHeader('X-Payment-ChainId', reqs.chainId.toString());

      throw new HttpException(
        {
          statusCode: HttpStatus.PAYMENT_REQUIRED,
          error: 'Payment Required',
          message: 'x402: Compute resource requires on-chain settlement before access is granted',
          paymentRequirements: {
            recipient: reqs.address,
            amount: reqs.amount,
            token: reqs.token,
            chainId: reqs.chainId,
          },
        },
        HttpStatus.PAYMENT_REQUIRED,
      );
    }

    // When payment header is present, verify on-chain settlement and unlock resource
    return await this.vendorService.verifyAndGrantAccess(paymentTxHash);
  }
}
