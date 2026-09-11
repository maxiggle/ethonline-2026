import { Test, TestingModule } from '@nestjs/testing';
import { HttpException, HttpStatus } from '@nestjs/common';
import { VendorController } from './vendor.controller';
import { VendorService } from './vendor.service';
import { OnChainExecutorService } from '../blockchain/on-chain-executor.service';
import { ActionStoreService } from '../actions/action-store.service';
import { PolicyEngineService } from '../policies/policy-engine.service';
import { Eip712Service } from '../crypto/eip712.service';
import { EventsGateway } from '../gateway/events.gateway';
import { TreasuryActionStatus } from '../domain/treasury-action.entity';
import { Response } from 'express';

describe('VendorController (x402 Protocol)', () => {
  let controller: VendorController;
  let vendorService: VendorService;
  let actionStore: ActionStoreService;
  let onChainExecutor: OnChainExecutorService;

  beforeEach(async () => {
    process.env.RPC_URL = 'https://sepolia.base.org';
    process.env.SAFE_ADDRESS = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
    process.env.GUARD_ADDRESS = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
    process.env.RELAYER_PRIVATE_KEY = '0xc9cff57134e18db409627a073e83b72a1a0d3a3c0c9b1852fd533667b8b408f1';
    process.env.CHAIN_ID = '84532';

    const module: TestingModule = await Test.createTestingModule({
      controllers: [VendorController],
      providers: [
        VendorService,
        OnChainExecutorService,
        ActionStoreService,
        PolicyEngineService,
        Eip712Service,
        EventsGateway,
      ],
    }).compile();

    controller = module.get<VendorController>(VendorController);
    vendorService = module.get<VendorService>(VendorService);
    actionStore = module.get<ActionStoreService>(ActionStoreService);
    onChainExecutor = module.get<OnChainExecutorService>(OnChainExecutorService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('HTTP 402 Payment Required Challenge', () => {
    it('should throw HTTP 402 with required payment headers when X-Payment-TxHash is missing', async () => {
      const headersMap: Record<string, string> = {};
      const mockRes = {
        setHeader: jest.fn((key: string, val: string) => {
          headersMap[key] = val;
        }),
      } as unknown as Response;

      try {
        await controller.getComputeResource(undefined, mockRes);
        fail('Should have thrown HttpException');
      } catch (err) {
        expect(err).toBeInstanceOf(HttpException);
        expect((err as HttpException).getStatus()).toBe(HttpStatus.PAYMENT_REQUIRED);

        // Verify headers
        expect(mockRes.setHeader).toHaveBeenCalledWith(
          'X-Payment-Address',
          '0x0000000000000000000000000000000000041c4e',
        );
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-Amount', '40000000');
        expect(mockRes.setHeader).toHaveBeenCalledWith(
          'X-Payment-Token',
          '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
        );
        expect(mockRes.setHeader).toHaveBeenCalledWith('X-Payment-ChainId', '84532');
      }
    });
  });

  describe('HTTP 200 OK Payment Verification & Access Grant', () => {
    it('should unlock compute resource when valid payment action exists in action store', async () => {
      const mockRes = {
        setHeader: jest.fn(),
      } as unknown as Response;

      const realTxHash = '0x98b5a4d65ba45e45c4ccc5a0fea57929d91bdd7bc19b46a5cba5dd32b7a12343';
      const action = actionStore.createAction({
        target: process.env.SAFE_ADDRESS!,
        value: '0',
        data: '0x',
        token: process.env.SAFE_ADDRESS!,
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '40000000',
        agentAddress: '0x1111111111111111111111111111111111111111',
        justification: 'x402 compute payment',
      });
      actionStore.updateStatus(action.id, TreasuryActionStatus.EXECUTED, { txHash: realTxHash });

      const response = await controller.getComputeResource(realTxHash, mockRes);

      expect(response.status).toBe('UNLOCKED');
      expect(response.resource).toBe('compute:dedicated-cluster:h100-gpu-node-01');
      expect(response.txHash).toBe(realTxHash);
      expect(response.sessionToken).toBeDefined();
      expect(response.details.allocatedVramGb).toBe(80);
    });

    it('should verify on-chain directly and unlock when tx exists on Base Sepolia', async () => {
      const mockRes = {
        setHeader: jest.fn(),
      } as unknown as Response;

      // Real mined deployment tx on Base Sepolia
      const realTxHash = '0x86fe4afdb35ffafdc67fba833eeb4b68657e1539564f01c08d431106402347c5';
      const response = await controller.getComputeResource(realTxHash, mockRes);

      expect(response.status).toBe('UNLOCKED');
      expect(response.txHash).toBe(realTxHash);
    });
  });
});
