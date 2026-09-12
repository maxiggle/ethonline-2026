import 'package:chapter2/features/bills/models/company_bill.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:equatable/equatable.dart';

enum BillsStatus { initial, loading, success, failure }

class BillsState extends Equatable {
  const BillsState({
    this.status = BillsStatus.initial,
    this.accounts = const [],
    this.bills = const [],
    this.bazaarResources = const [],
    this.isPayingBill = false,
    this.payingBillId,
    this.pendingEscalationAction,
    this.lastPaymentNotice,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCategory = 'ALL',
    this.selectedResource,
    this.isInvokingService = false,
    this.lastInvocationResult,
  });

  final BillsStatus status;
  final List<ConnectedAccount> accounts;
  final List<CompanyBill> bills;
  final List<BazaarResource> bazaarResources;
  final bool isPayingBill;
  final String? payingBillId;
  final TreasuryAction? pendingEscalationAction;
  final String? lastPaymentNotice;
  final String? errorMessage;
  final String searchQuery;
  final String selectedCategory;
  final BazaarResource? selectedResource;
  final bool isInvokingService;
  final BazaarInvocationResult? lastInvocationResult;

  List<BazaarResource> get displayedBazaarResources {
    var items = List<BazaarResource>.from(bazaarResources);

    // Category filter
    if (selectedCategory != 'ALL') {
      final cat = selectedCategory.toLowerCase();
      items = items.where((r) {
        final tags = r.tags.map((t) => t.toLowerCase()).toList();
        final name = r.serviceName.toLowerCase();
        if (cat == 'weather') {
          return tags.contains('weather') || name.contains('weather');
        } else if (cat == 'compute' || cat == 'ai') {
          return tags.contains('gpu') || tags.contains('ai') || tags.contains('compute') || name.contains('compute') || name.contains('vertex');
        } else if (cat == 'security') {
          return tags.contains('security') || tags.contains('waf') || name.contains('security');
        } else if (cat == 'rpc') {
          return tags.contains('rpc') || tags.contains('node') || name.contains('rpc');
        }
        return tags.any((t) => t.contains(cat)) || name.contains(cat);
      }).toList();
    }

    // Text search filter
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      items = items.where((r) {
        final name = r.serviceName.toLowerCase();
        final desc = r.description.toLowerCase();
        final tags = r.tags.map((t) => t.toLowerCase()).toList();
        final resUrl = r.resource.toLowerCase();

        // Exact substring
        if (name.contains(q) || desc.contains(q) || tags.any((t) => t.contains(q)) || resUrl.contains(q)) {
          return true;
        }

        // Token match
        return tokens.any((tok) =>
            name.contains(tok) ||
            desc.contains(tok) ||
            tags.any((t) => t.contains(tok)));
      }).toList();
    }

    return items;
  }

  BillsState copyWith({
    BillsStatus? status,
    List<ConnectedAccount>? accounts,
    List<CompanyBill>? bills,
    List<BazaarResource>? bazaarResources,
    bool? isPayingBill,
    String? payingBillId,
    TreasuryAction? pendingEscalationAction,
    String? lastPaymentNotice,
    String? errorMessage,
    String? searchQuery,
    String? selectedCategory,
    BazaarResource? selectedResource,
    bool clearSelectedResource = false,
    bool? isInvokingService,
    BazaarInvocationResult? lastInvocationResult,
    bool clearLastInvocation = false,
  }) {
    return BillsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      bills: bills ?? this.bills,
      bazaarResources: bazaarResources ?? this.bazaarResources,
      isPayingBill: isPayingBill ?? this.isPayingBill,
      payingBillId: payingBillId,
      pendingEscalationAction: pendingEscalationAction,
      lastPaymentNotice: lastPaymentNotice ?? this.lastPaymentNotice,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedResource: clearSelectedResource ? null : (selectedResource ?? this.selectedResource),
      isInvokingService: isInvokingService ?? this.isInvokingService,
      lastInvocationResult: clearLastInvocation ? null : (lastInvocationResult ?? this.lastInvocationResult),
    );
  }

  @override
  List<Object?> get props => [
        status,
        accounts,
        bills,
        bazaarResources,
        isPayingBill,
        payingBillId,
        pendingEscalationAction,
        lastPaymentNotice,
        errorMessage,
        searchQuery,
        selectedCategory,
        selectedResource,
        isInvokingService,
        lastInvocationResult,
      ];
}
