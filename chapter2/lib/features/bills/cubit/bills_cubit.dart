import 'package:chapter2/features/bills/cubit/bills_state.dart';
import 'package:chapter2/features/bills/models/company_bill.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BillsCubit extends Cubit<BillsState> {
  BillsCubit({required Chapter2ApiService apiService})
      : _apiService = apiService,
        super(const BillsState());

  final Chapter2ApiService _apiService;

  Future<void> loadAll() async {
    emit(state.copyWith(status: BillsStatus.loading));
    try {
      final accountsFuture = _apiService.fetchConnectedAccounts();
      final billsFuture = _apiService.fetchCompanyBills();
      final bazaarFuture = _apiService.fetchBazaarResources();

      final results = await Future.wait([accountsFuture, billsFuture, bazaarFuture]);

      emit(state.copyWith(
        status: BillsStatus.success,
        accounts: results[0] as dynamic,
        bills: results[1] as dynamic,
        bazaarResources: results[2] as dynamic,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: BillsStatus.failure,
        errorMessage: 'Failed to load enterprise bills: $e',
      ));
    }
  }

  Future<void> connectAccount({
    required String provider,
    required String name,
    required String organization,
    required String accountId,
    List<String>? projects,
  }) async {
    try {
      await _apiService.connectAccount(
        provider: provider,
        name: name,
        organization: organization,
        accountId: accountId,
        projects: projects,
      );
      await loadAll();
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to connect account: $e'));
    }
  }

  Future<void> payBill(String billId, {String? agentAddress}) async {
    emit(state.copyWith(
      isPayingBill: true,
      payingBillId: billId,
      lastPaymentNotice: null,
      errorMessage: null,
    ));

    try {
      final response = await _apiService.payCompanyBill(
        billId,
        agentAddress: agentAddress,
      );

      if (response.requiresHumanApproval) {
        emit(state.copyWith(
          isPayingBill: false,
          payingBillId: null,
          pendingEscalationAction: response.action,
          lastPaymentNotice:
              'Invoice ${response.bill.invoiceNumber} (\$${response.bill.amountUsdc.toStringAsFixed(0)} USDC) exceeds daily limit. ESCALATED for Face ID biometric sign-off!',
        ));
      } else {
        final txInfo = response.bill.txHash != null || response.action.txHash != null
            ? ' Tx: ${response.bill.txHash ?? response.action.txHash}'
            : '';
        emit(state.copyWith(
          isPayingBill: false,
          payingBillId: null,
          lastPaymentNotice:
              'Invoice ${response.bill.invoiceNumber} (\$${response.bill.amountUsdc.toStringAsFixed(0)} USDC) ALLOWED & Paid on Base Sepolia!$txInfo',
        ));
      }

      await loadAll();
    } catch (e) {
      emit(state.copyWith(
        isPayingBill: false,
        payingBillId: null,
        errorMessage: 'Payment dispatch failed: $e',
      ));
    }
  }

  void searchBazaar(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setBazaarCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  void selectBazaarResource(BazaarResource? resource) {
    emit(state.copyWith(
      selectedResource: resource,
      clearSelectedResource: resource == null,
      clearLastInvocation: true,
    ));
  }

  Future<void> invokeBazaarService(
    BazaarResource resource, {
    Map<String, dynamic>? params,
    String? agentAddress,
  }) async {
    emit(state.copyWith(
      isInvokingService: true,
      selectedResource: resource,
      clearLastInvocation: true,
      errorMessage: null,
    ));

    try {
      final result = await _apiService.invokeBazaarService(
        resourceUrl: resource.resource,
        method: resource.method,
        params: params,
        agentAddress: agentAddress,
      );

      if (result.isEscalated) {
        emit(state.copyWith(
          isInvokingService: false,
          lastInvocationResult: result,
          pendingEscalationAction: result.action,
          lastPaymentNotice:
              'Service "${result.serviceName}" (\$${result.costUsdc.toStringAsFixed(2)} USDC) exceeds daily autonomous cap. ESCALATED for Face ID sign-off!',
        ));
      } else {
        final txInfo = result.txHash != null ? ' Tx: ${result.txHash}' : '';
        emit(state.copyWith(
          isInvokingService: false,
          lastInvocationResult: result,
          lastPaymentNotice:
              'x402 challenge settled for "${result.serviceName}"! Executed on Base Sepolia.$txInfo',
        ));
      }

      await loadAll();
    } catch (e) {
      emit(state.copyWith(
        isInvokingService: false,
        errorMessage: 'Failed to call Bazaar service: $e',
      ));
    }
  }

  void clearLastInvocation() {
    emit(state.copyWith(clearLastInvocation: true));
  }

  void clearPendingEscalation() {
    emit(state.copyWith(pendingEscalationAction: null));
  }
}
