import 'package:equatable/equatable.dart';

/// One x402 catalog entry from `GET /discovery/resources`, restricted to the
/// Base Sepolia accept the app can pay with. Entries with no
/// `eip155:84532` accept are not represented by this model at all — see
/// [BazaarService.fromCatalogItem].
class BazaarService extends Equatable {
  const BazaarService({
    required this.resourceUrl,
    required this.serviceName,
    required this.description,
    required this.tags,
    required this.method,
    required this.queryParams,
    required this.outputExample,
    required this.priceAtomicUnits,
    required this.payTo,
    required this.network,
  });

  static const _baseSepoliaNetwork = 'eip155:84532';

  final String resourceUrl;
  final String serviceName;
  final String description;
  final List<String> tags;
  final String method;

  /// Query parameter name to the catalog's example value, e.g. `{'city':
  /// 'Lagos'}`. Used to prefill the detail sheet's input fields.
  final Map<String, String> queryParams;
  final Map<String, dynamic> outputExample;
  final String priceAtomicUnits;
  final String payTo;
  final String network;

  /// The resource path shown in search and the detail sheet, e.g.
  /// `/x402/weather` from `https://host/x402/weather`.
  String get resourcePath => Uri.tryParse(resourceUrl)?.path ?? resourceUrl;

  /// A short human label for [network]. Every entry this app shows is on
  /// Base Sepolia, since [fromCatalogItem] filters to that accept.
  String get networkLabel => network == _baseSepoliaNetwork ? 'Base Sepolia' : network;

  /// Parses one `items[]` entry of the catalog response. Returns `null`,
  /// meaning the catalog card must not show this entry, when it has no
  /// `network == 'eip155:84532'` accept or no resource URL.
  static BazaarService? fromCatalogItem(Map<String, dynamic> json) {
    final resourceUrl = json['resource'] as String?;
    if (resourceUrl == null || resourceUrl.isEmpty) return null;

    final accepts = json['accepts'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? matchingAccept;
    for (final rawAccept in accepts) {
      final accept = Map<String, dynamic>.from(rawAccept as Map);
      if (accept['network'] == _baseSepoliaNetwork) {
        matchingAccept = accept;
        break;
      }
    }
    if (matchingAccept == null) return null;

    final extensions = json['extensions'] as Map<String, dynamic>? ?? const {};
    final bazaar = extensions['bazaar'] as Map<String, dynamic>? ?? const {};
    final info = Map<String, dynamic>.from(bazaar['info'] as Map? ?? const {});
    final input = Map<String, dynamic>.from(info['input'] as Map? ?? const {});
    final output = Map<String, dynamic>.from(info['output'] as Map? ?? const {});
    final rawQueryParams = Map<String, dynamic>.from(input['queryParams'] as Map? ?? const {});

    return BazaarService(
      resourceUrl: resourceUrl,
      serviceName: info['serviceName'] as String? ?? resourceUrl,
      description: info['description'] as String? ?? '',
      tags: List<String>.from(info['tags'] as List? ?? const []),
      method: input['method'] as String? ?? 'GET',
      queryParams: rawQueryParams.map((key, value) => MapEntry(key, value.toString())),
      outputExample: Map<String, dynamic>.from(output['example'] as Map? ?? const {}),
      priceAtomicUnits: matchingAccept['amount']?.toString() ?? '0',
      payTo: matchingAccept['payTo'] as String? ?? '',
      network: matchingAccept['network'] as String? ?? _baseSepoliaNetwork,
    );
  }

  @override
  List<Object?> get props => [
        resourceUrl,
        serviceName,
        description,
        tags,
        method,
        queryParams,
        outputExample,
        priceAtomicUnits,
        payTo,
        network,
      ];
}
