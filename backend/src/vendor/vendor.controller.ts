import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  Headers,
  Req,
  Res,
  UseGuards,
  HttpException,
  HttpStatus,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { Response } from 'express';
import { IsArray, IsEthereumAddress, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import {
  VendorService,
  ComputeResourceGrant,
  ConnectedAccount,
  CompanyBill,
} from './vendor.service';
import { ActionsController } from '../actions/actions.controller';
import { ProposeActionDto } from '../domain/dto/propose-action.dto';
import { PrivyAuthGuard } from '../auth/guards/privy-auth.guard';
import { AuthenticatedRequest } from '../auth/interfaces/authenticated-request.interface';
import { AgentsService } from '../agents/agents.service';
import { InvokeServiceDto } from './dto/invoke-service.dto';

export class ConnectAccountDto {
  @IsIn(['google_cloud', 'aws', 'alchemy', 'openai'])
  provider: 'google_cloud' | 'aws' | 'alchemy' | 'openai';

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  organization: string;

  @IsString()
  @IsNotEmpty()
  accountId: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  projects?: string[];
}

export class PayBillDto {
  @IsEthereumAddress()
  agentAddress: string;
}

/**
 * Account, billing and invocation routes act on the treasury and require an authenticated agent owner.
 * x402 resource routes (bills/:id, compute, weather) stay public: the on-chain payment is the authorization.
 */
@Controller('vendor')
export class VendorController {
  constructor(
    private readonly vendorService: VendorService,
    private readonly actionsController: ActionsController,
    private readonly agentsService: AgentsService,
  ) {}

  @Get('accounts')
  @UseGuards(PrivyAuthGuard)
  getConnectedAccounts(): ConnectedAccount[] {
    return this.vendorService.getConnectedAccounts();
  }

  @Post('accounts/connect')
  @UseGuards(PrivyAuthGuard)
  connectAccount(@Body() dto: ConnectAccountDto): ConnectedAccount {
    return this.vendorService.connectAccount(dto);
  }

  @Post('accounts/:id/disconnect')
  @UseGuards(PrivyAuthGuard)
  disconnectAccount(@Param('id') id: string): { success: boolean } {
    const ok = this.vendorService.disconnectAccount(id);
    return { success: ok };
  }

  @Get('bills')
  @UseGuards(PrivyAuthGuard)
  getBills(): CompanyBill[] {
    return this.vendorService.getBills();
  }

  @Get('bills/:id')
  async getBill(
    @Param('id') id: string,
    @Headers('x-payment-txhash') paymentTxHash: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CompanyBill | ComputeResourceGrant> {
    const bill = this.vendorService.getBillById(id);
    if (!bill) {
      throw new NotFoundException(`Company bill with ID '${id}' not found`);
    }

    // If payment header is present, verify on-chain settlement and unlock
    if (paymentTxHash) {
      this.vendorService.markBillSettled(id, paymentTxHash);
      return await this.vendorService.verifyAndGrantAccess(paymentTxHash);
    }

    // If already settled in store, return the settled bill
    if (bill.status === 'SETTLED_200' && bill.unlockedGrant) {
      return bill;
    }

    // Set standard x402 HTTP challenge headers
    res.setHeader('X-Payment-Address', bill.paymentRequirements.address);
    res.setHeader('X-Payment-Amount', bill.paymentRequirements.amount);
    res.setHeader('X-Payment-Token', bill.paymentRequirements.token);
    res.setHeader('X-Payment-ChainId', bill.paymentRequirements.chainId.toString());
    res.setHeader('X-Payment-Identifier', bill.paymentIdentifier);

    throw new HttpException(
      {
        statusCode: HttpStatus.PAYMENT_REQUIRED,
        error: 'Payment Required',
        message: `x402: Service '${bill.serviceName}' invoice ${bill.invoiceNumber} requires on-chain settlement before access is granted`,
        paymentRequirements: {
          recipient: bill.paymentRequirements.address,
          amount: bill.paymentRequirements.amount,
          token: bill.paymentRequirements.token,
          chainId: bill.paymentRequirements.chainId,
          paymentIdentifier: bill.paymentIdentifier,
          invoiceNumber: bill.invoiceNumber,
          accountId: bill.accountId,
        },
      },
      HttpStatus.PAYMENT_REQUIRED,
    );
  }

  @Post('bills/:id/pay')
  @UseGuards(PrivyAuthGuard)
  async payBill(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: PayBillDto,
  ): Promise<{
    bill: CompanyBill;
    action: any;
    decision: any;
    typedData?: any;
  }> {
    const bill = this.vendorService.getBillById(id);
    if (!bill) {
      throw new NotFoundException(`Company bill with ID '${id}' not found`);
    }

    await this.agentsService.assertAgentOwnership(request.user.id, dto.agentAddress);

    // Check account connection status
    const accounts = this.vendorService.getConnectedAccounts();
    const account = accounts.find((a) => a.accountId === bill.accountId);
    if (account && account.status === 'DISCONNECTED') {
      throw new BadRequestException(
        `Cannot pay bill: Connected account '${bill.accountId}' is currently disconnected.`,
      );
    }

    const proposePayload: ProposeActionDto = {
      target: bill.paymentRequirements.token,
      value: '0',
      data: '0xa9059cbb',
      token: bill.paymentRequirements.token,
      recipient: bill.paymentRequirements.address,
      amount: bill.amount,
      agentAddress: dto.agentAddress,
      justification: `${bill.serviceName} [${bill.invoiceNumber}]: ${bill.description} (Identifier: ${bill.paymentIdentifier})`,
    };

    const proposalResult = await this.actionsController.proposeAction(proposePayload);

    // If auto-approved/executed with txHash, mark the bill settled
    if (proposalResult.action.txHash) {
      this.vendorService.markBillSettled(bill.id, proposalResult.action.txHash);
    }

    return {
      bill: this.vendorService.getBillById(id) || bill,
      action: proposalResult.action,
      decision: proposalResult.decision,
      typedData: proposalResult.typedData,
    };
  }

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

  @Get('weather')
  async getWeather(
    @Query('city') city: string | undefined,
    @Headers('x-payment-txhash') paymentTxHash: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ): Promise<Record<string, any>> {
    const cityName = city || 'San Francisco';
    const reqs = {
      address: this.vendorService.vendorAddress,
      amount: '1000000', // 1.00 USDC
      token: this.vendorService.tokenAddress,
      chainId: this.vendorService.chainId,
      paymentIdentifier: 'weather_oracle_inv_004',
    };

    if (!paymentTxHash) {
      res.setHeader('X-Payment-Address', reqs.address);
      res.setHeader('X-Payment-Amount', reqs.amount);
      res.setHeader('X-Payment-Token', reqs.token);
      res.setHeader('X-Payment-ChainId', reqs.chainId.toString());
      res.setHeader('X-Payment-Identifier', reqs.paymentIdentifier);

      throw new HttpException(
        {
          statusCode: HttpStatus.PAYMENT_REQUIRED,
          error: 'Payment Required',
          message:
            "x402: Service 'AccuWeather & Climate Intelligence Oracle' requires on-chain payment of 1.00 USDC",
          paymentRequirements: reqs,
        },
        HttpStatus.PAYMENT_REQUIRED,
      );
    }

    return this.vendorService.getWeatherTelemetry(cityName, paymentTxHash);
  }

  @Post('invoke')
  @UseGuards(PrivyAuthGuard)
  async invokeService(@Req() request: AuthenticatedRequest, @Body() dto: InvokeServiceDto) {
    await this.agentsService.assertAgentOwnership(request.user.id, dto.agentAddress);
    return await this.vendorService.invokeService(
      dto.resourceUrl,
      dto.method,
      dto.params,
      dto.agentAddress,
    );
  }
}
