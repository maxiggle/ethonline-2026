import { RoutesConfig } from '@x402/core/server';
import { X402Config } from './x402.config';

/**
 * x402 v2 route table: price, network and payTo per resource, in the SDK's RoutesConfig shape.
 */
export function buildX402Routes(config: X402Config): RoutesConfig {
  return {
    'GET /x402/weather': {
      accepts: {
        scheme: 'exact',
        price: '$0.01',
        network: config.network,
        payTo: config.payToAddress,
      },
      description: 'Real-time weather telemetry from Open-Meteo for a given city',
      mimeType: 'application/json',
      serviceName: 'Open-Meteo Weather Oracle',
      tags: ['weather', 'climate', 'oracle', 'open-meteo'],
    },
    'GET /x402/chain-report': {
      accepts: {
        scheme: 'exact',
        price: '$2.00',
        network: config.network,
        payTo: config.payToAddress,
        maxTimeoutSeconds: 900,
      },
      description: 'Live Base Sepolia chain report: latest block, fee data and USDC supply',
      mimeType: 'application/json',
      serviceName: 'Base Sepolia Chain Report',
      tags: ['chain', 'base-sepolia', 'rpc', 'usdc'],
    },
    'GET /x402/partner-feed': {
      accepts: {
        scheme: 'exact',
        price: '$0.05',
        network: config.network,
        payTo: config.partnerPayToAddress,
      },
      description: 'Partner chain data feed (demo: unapproved payee, expected to BLOCK)',
      mimeType: 'application/json',
      serviceName: 'Partner Chain Feed',
      tags: ['chain', 'base-sepolia', 'partner'],
    },
  };
}
