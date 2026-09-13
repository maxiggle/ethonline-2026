import 'dart:async';

import 'package:chapter2/features/services/cubit/services_state.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/remote/services_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _purchasesPollInterval = Duration(seconds: 3);

/// Drives the Services tab: the x402 catalog (fetched once, refetched on
/// pull-to-refresh or Retry), a local text search over the already-fetched
/// catalog, and the operator's purchase requests (polled every 3 s while the
/// tab is visible, the same approach as [X402ApprovalsCubit]).
class ServicesCubit extends Cubit<ServicesState> {
  ServicesCubit({required ServicesApiService apiService})
      : _apiService = apiService,
        super(const ServicesState());

  final ServicesApiService _apiService;
  Timer? _purchasesPollingTimer;

  /// Fetches the catalog only if it has not already loaded (or is
  /// currently loading). Safe to call every time the tab appears.
  Future<void> loadCatalogOnce() async {
    if (state.catalogStatus == ServicesCatalogStatus.success || state.catalogStatus == ServicesCatalogStatus.loading) {
      return;
    }
    await refreshCatalog();
  }

  /// Always refetches the catalog, for pull-to-refresh and the error
  /// state's Retry button.
  Future<void> refreshCatalog() async {
    emit(state.copyWith(catalogStatus: ServicesCatalogStatus.loading, clearCatalogError: true));
    try {
      final catalog = await _apiService.fetchCatalog();
      emit(state.copyWith(catalogStatus: ServicesCatalogStatus.success, catalog: catalog));
    } catch (error) {
      emit(state.copyWith(catalogStatus: ServicesCatalogStatus.failure, catalogError: _describeError(error)));
    }
  }

  void updateSearchQuery(String query) => emit(state.copyWith(searchQuery: query));

  void clearSearchQuery() => emit(state.copyWith(searchQuery: ''));

  /// Starts polling `fetchPurchaseRequests` every 3 seconds. Call
  /// [stopPurchasesPolling] when the Services tab is no longer visible.
  void startPurchasesPolling() {
    _purchasesPollingTimer?.cancel();
    unawaited(refreshPurchases());
    _purchasesPollingTimer = Timer.periodic(_purchasesPollInterval, (_) => refreshPurchases());
  }

  void stopPurchasesPolling() {
    _purchasesPollingTimer?.cancel();
    _purchasesPollingTimer = null;
  }

  Future<void> refreshPurchases() async {
    try {
      final purchases = await _apiService.fetchPurchaseRequests();
      emit(state.copyWith(purchases: purchases, clearPurchasesError: true));
    } catch (error) {
      emit(state.copyWith(purchasesError: _describeError(error)));
    }
  }

  Future<PurchaseRequest?> createPurchaseRequest({
    required String agentAddress,
    required String resourceUrl,
    required Map<String, String> queryParams,
    required String justification,
  }) async {
    emit(state.copyWith(createStatus: ServicesCreateStatus.submitting, clearCreateError: true));
    try {
      final request = await _apiService.createPurchaseRequest(
        agentAddress: agentAddress,
        resourceUrl: resourceUrl,
        queryParams: queryParams,
        justification: justification,
      );
      emit(state.copyWith(createStatus: ServicesCreateStatus.success));
      unawaited(refreshPurchases());
      return request;
    } catch (error) {
      emit(state.copyWith(createStatus: ServicesCreateStatus.failure, createError: _describeError(error)));
      return null;
    }
  }

  String _describeError(Object error) => error.toString();

  @override
  Future<void> close() {
    stopPurchasesPolling();
    return super.close();
  }
}
