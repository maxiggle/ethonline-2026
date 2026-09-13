import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/services/cubit/services_cubit.dart';
import 'package:chapter2/features/services/cubit/services_state.dart';
import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/utils/purchase_status_presenter.dart';
import 'package:chapter2/features/services/view/service_detail_sheet.dart';
import 'package:chapter2/features/x402_approvals/utils/usdc_amount_formatter.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Services tab: the live x402 catalog with local search, and the
/// operator's own purchase requests. Embedded inside [MainShellScreen],
/// like Home and Approvals.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  ServicesCubit? _cubit;
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<ServicesCubit>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ServicesCubit>();
      cubit.loadCatalogOnce();
      cubit.startPurchasesPolling();
    });
  }

  @override
  void dispose() {
    // Read the cubit via the cached reference, not `context.read`: by the
    // time dispose() runs the BlocProvider ancestor may already be
    // deactivated (e.g. when the whole tree is torn down together).
    _cubit?.stopPurchasesPolling();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<ServicesCubit, ServicesState>(
        builder: (context, state) {
          if (_searchController.text != state.searchQuery) {
            _searchController.value = _searchController.value.copyWith(
              text: state.searchQuery,
              selection: TextSelection.collapsed(offset: state.searchQuery.length),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<ServicesCubit>().refreshCatalog(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Text('Services', style: AppTextStyles.xxl(context, fontWeight: AppTextStyles.extraBold)),
                const SizedBox(height: 4),
                Text(
                  'Browse x402 services and ask your agent to pay.',
                  style: AppTextStyles.sm(context, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _buildSearchField(context, state),
                const SizedBox(height: 16),
                ..._buildCatalogSection(context, state),
                const SizedBox(height: 24),
                _buildPurchasesSection(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, ServicesState state) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => context.read<ServicesCubit>().updateSearchQuery(value),
      decoration: InputDecoration(
        hintText: 'Search services',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
        suffixIcon: state.searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  context.read<ServicesCubit>().clearSearchQuery();
                },
              )
            : null,
      ),
    );
  }

  List<Widget> _buildCatalogSection(BuildContext context, ServicesState state) {
    if (state.catalogStatus == ServicesCatalogStatus.loading && state.catalog.isEmpty) {
      return [_buildLoadingCard(context, 'Loading services...')];
    }
    if (state.catalogStatus == ServicesCatalogStatus.failure && state.catalog.isEmpty) {
      return [
        _buildErrorCard(
          context,
          state.catalogError ?? 'Could not load services.',
          onRetry: () => context.read<ServicesCubit>().refreshCatalog(),
        ),
      ];
    }

    final filtered = state.filteredCatalog;
    if (filtered.isEmpty && state.isSearching) {
      return [_buildEmptySearchState(context, state.searchQuery)];
    }
    if (filtered.isEmpty) {
      return [_buildEmptyCard(context, 'No services are available right now.')];
    }

    return filtered
        .map((service) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildServiceCard(context, service),
            ))
        .toList();
  }

  Widget _buildEmptySearchState(BuildContext context, String query) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No services match "$query"', style: AppTextStyles.md(context)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              context.read<ServicesCubit>().clearSearchQuery();
            },
            child: const Text('Clear search'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, BazaarService service) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showServiceDetailSheet(context, service: service),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    service.serviceName,
                    style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${UsdcAmountFormatter.format(service.priceAtomicUnits)}',
                  style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              service.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sm(context, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in service.tags.take(3)) _buildTagChip(context, tag),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(service.networkLabel, style: AppTextStyles.xs(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(tag, style: AppTextStyles.xs(context)),
    );
  }

  Widget _buildPurchasesSection(BuildContext context, ServicesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your purchases', style: AppTextStyles.lg(context, fontWeight: AppTextStyles.bold)),
        const SizedBox(height: 12),
        if (state.purchases.isEmpty)
          _buildEmptyCard(context, 'No purchase requests yet. Pick a service above to ask your agent to pay.')
        else
          ...state.purchases.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPurchaseRow(context, request),
            ),
          ),
      ],
    );
  }

  Widget _buildPurchaseRow(BuildContext context, PurchaseRequest request) {
    final chip = PurchaseStatusChip.forRequest(request);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.router.push(
        PurchaseDetailRoute(purchaseRequestId: request.id, initialPurchase: request),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.serviceName,
                    style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${UsdcAmountFormatter.format(request.amountAtomicUnits)} USDC · ${_relativeTime(request.createdAt)}',
                    style: AppTextStyles.xs(context, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chip.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: chip.border),
              ),
              child: Text(
                chip.label,
                style: AppTextStyles.xs(context, color: chip.textColor, fontWeight: AppTextStyles.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.sm(context, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTextStyles.sm(context, color: AppColors.blockText)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
    );
  }

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
