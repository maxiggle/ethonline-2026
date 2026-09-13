import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:equatable/equatable.dart';

enum ServicesCatalogStatus { initial, loading, success, failure }

enum ServicesCreateStatus { idle, submitting, success, failure }

class ServicesState extends Equatable {
  const ServicesState({
    this.catalogStatus = ServicesCatalogStatus.initial,
    this.catalog = const [],
    this.catalogError,
    this.searchQuery = '',
    this.purchases = const [],
    this.purchasesError,
    this.createStatus = ServicesCreateStatus.idle,
    this.createError,
  });

  final ServicesCatalogStatus catalogStatus;
  final List<BazaarService> catalog;
  final String? catalogError;
  final String searchQuery;
  final List<PurchaseRequest> purchases;
  final String? purchasesError;
  final ServicesCreateStatus createStatus;
  final String? createError;

  bool get isSearching => searchQuery.trim().isNotEmpty;

  /// [catalog] filtered by [searchQuery], case-insensitive, against the
  /// service name, description, tags and resource path. Computed locally on
  /// every keystroke — no network call.
  List<BazaarService> get filteredCatalog {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return catalog;
    return catalog.where((service) {
      if (service.serviceName.toLowerCase().contains(query)) return true;
      if (service.description.toLowerCase().contains(query)) return true;
      if (service.resourcePath.toLowerCase().contains(query)) return true;
      return service.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  ServicesState copyWith({
    ServicesCatalogStatus? catalogStatus,
    List<BazaarService>? catalog,
    String? catalogError,
    bool clearCatalogError = false,
    String? searchQuery,
    List<PurchaseRequest>? purchases,
    String? purchasesError,
    bool clearPurchasesError = false,
    ServicesCreateStatus? createStatus,
    String? createError,
    bool clearCreateError = false,
  }) {
    return ServicesState(
      catalogStatus: catalogStatus ?? this.catalogStatus,
      catalog: catalog ?? this.catalog,
      catalogError: clearCatalogError ? null : (catalogError ?? this.catalogError),
      searchQuery: searchQuery ?? this.searchQuery,
      purchases: purchases ?? this.purchases,
      purchasesError: clearPurchasesError ? null : (purchasesError ?? this.purchasesError),
      createStatus: createStatus ?? this.createStatus,
      createError: clearCreateError ? null : (createError ?? this.createError),
    );
  }

  @override
  List<Object?> get props => [
        catalogStatus,
        catalog,
        catalogError,
        searchQuery,
        purchases,
        purchasesError,
        createStatus,
        createError,
      ];
}
