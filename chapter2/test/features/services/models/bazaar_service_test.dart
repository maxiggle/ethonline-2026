import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped exactly like a live `GET /discovery/resources` entry (see
/// TICKET-MOBILE-003's "Data sources" section and the backend's real
/// response for `/x402/weather`).
Map<String, dynamic> _weatherCatalogItem() => {
      'resource': 'https://chapter2-backend.onrender.com/x402/weather',
      'type': 'http',
      'x402Version': 2,
      'accepts': [
        {
          'network': 'eip155:84532',
          'asset': '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
          'amount': '10000',
          'payTo': '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f',
          'scheme': 'exact',
        },
      ],
      'extensions': {
        'bazaar': {
          'info': {
            'serviceName': 'Open-Meteo Weather Oracle',
            'description': 'Real-time weather telemetry from Open-Meteo for a given city',
            'tags': ['weather', 'climate', 'oracle', 'open-meteo'],
            'input': {
              'type': 'http',
              'method': 'GET',
              'queryParams': {'city': 'Lagos'},
            },
            'output': {
              'type': 'json',
              'example': {
                'city': 'Lagos',
                'temperatureC': 29.4,
                'humidity': 77,
                'windSpeedKph': 11.2,
                'source': 'open-meteo.com',
              },
            },
          },
        },
      },
    };

void main() {
  group('BazaarService.fromCatalogItem', () {
    test('parses every field of a live-shaped catalog entry', () {
      final service = BazaarService.fromCatalogItem(_weatherCatalogItem());

      expect(service, isNotNull);
      expect(service!.resourceUrl, 'https://chapter2-backend.onrender.com/x402/weather');
      expect(service.serviceName, 'Open-Meteo Weather Oracle');
      expect(service.description, 'Real-time weather telemetry from Open-Meteo for a given city');
      expect(service.tags, ['weather', 'climate', 'oracle', 'open-meteo']);
      expect(service.method, 'GET');
      expect(service.queryParams, {'city': 'Lagos'});
      expect(service.outputExample['city'], 'Lagos');
      expect(service.outputExample['temperatureC'], 29.4);
      expect(service.priceAtomicUnits, '10000');
      expect(service.payTo, '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f');
      expect(service.network, 'eip155:84532');
      expect(service.resourcePath, '/x402/weather');
      expect(service.networkLabel, 'Base Sepolia');
    });

    test('is skipped when there is no eip155:84532 accept', () {
      final item = _weatherCatalogItem();
      item['accepts'] = [
        {
          'network': 'eip155:8453',
          'asset': '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
          'amount': '10000',
          'payTo': '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f',
          'scheme': 'exact',
        },
      ];

      expect(BazaarService.fromCatalogItem(item), isNull);
    });

    test('is skipped when there are no accepts at all', () {
      final item = _weatherCatalogItem();
      item['accepts'] = <dynamic>[];

      expect(BazaarService.fromCatalogItem(item), isNull);
    });

    test('is skipped when the resource URL is missing', () {
      final item = _weatherCatalogItem();
      item.remove('resource');

      expect(BazaarService.fromCatalogItem(item), isNull);
    });

    test('defaults to GET and empty inputs when bazaar info omits them', () {
      final item = _weatherCatalogItem();
      (item['extensions'] as Map)['bazaar'] = {
        'info': {
          'serviceName': 'Base Sepolia Chain Report',
          'description': 'Live Base Sepolia chain report',
          'tags': <String>[],
        },
      };

      final service = BazaarService.fromCatalogItem(item);

      expect(service, isNotNull);
      expect(service!.method, 'GET');
      expect(service.queryParams, isEmpty);
      expect(service.outputExample, isEmpty);
    });
  });
}
