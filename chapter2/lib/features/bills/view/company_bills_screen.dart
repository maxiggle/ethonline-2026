import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/bills/cubit/bills_cubit.dart';
import 'package:chapter2/features/bills/cubit/bills_state.dart';
import 'package:chapter2/features/bills/models/company_bill.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompanyBillsScreen extends StatefulWidget {
  const CompanyBillsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CompanyBillsScreen()));
  }

  @override
  State<CompanyBillsScreen> createState() => _CompanyBillsScreenState();
}

class _CompanyBillsScreenState extends State<CompanyBillsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      context.read<BillsCubit>();
      return _buildScaffold(context);
    } catch (_) {
      return BlocProvider(
        create: (_) =>
            BillsCubit(apiService: locator<Chapter2ApiService>())..loadAll(),
        child: Builder(builder: (ctx) => _buildScaffold(ctx)),
      );
    }
  }

  Widget _buildScaffold(BuildContext context) {
    return BlocListener<BillsCubit, BillsState>(
      listenWhen: (prev, curr) =>
          prev.pendingEscalationAction != curr.pendingEscalationAction &&
          curr.pendingEscalationAction != null,
      listener: (context, state) {
        if (state.pendingEscalationAction != null) {
          _showBiometricApprovalSheet(context, state.pendingEscalationAction!);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        appBar: AppBar(
          backgroundColor: AppColors.screenBackground,
          elevation: 0,
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Bills & x402 Hub',
                style: AppTextStyles.lg(context, color: Colors.white),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.allow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Base Sepolia Safe • HTTP 402 Paywalls',
                      style: AppTextStyles.mono(
                        context,
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.brandPrimary,
              ),
              onPressed: () => context.read<BillsCubit>().loadAll(),
            ),
          ],
        ),
        body: BlocBuilder<BillsCubit, BillsState>(
          builder: (context, state) {
            if (state.status == BillsStatus.loading && state.bills.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              );
            }

            return RefreshIndicator(
              color: AppColors.brandPrimary,
              backgroundColor: AppColors.screenBackgroundElevated,
              onRefresh: () => context.read<BillsCubit>().loadAll(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status notice banner if present
                    if (state.lastPaymentNotice != null) ...[
                      _buildNoticeBanner(context, state.lastPaymentNotice!),
                      const SizedBox(height: 16),
                    ],

                    if (state.errorMessage != null) ...[
                      _buildErrorBanner(context, state.errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Section 1: Connected Corporate Accounts
                    _buildConnectedAccountsSection(context, state),
                    const SizedBox(height: 24),

                    // Section 2: Active Corporate Invoices & Paywalls
                    _buildBillsSection(context, state),
                    const SizedBox(height: 24),

                    // Section 3: Bazaar Discovery Catalog
                    _buildBazaarDiscoverySection(context, state),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoticeBanner(BuildContext context, String notice) {
    final isEscalated = notice.contains('ESCALATED');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEscalated
            ? AppColors.escalate.withValues(alpha: 0.12)
            : AppColors.allow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEscalated
              ? AppColors.escalate.withValues(alpha: 0.4)
              : AppColors.allow.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEscalated ? Icons.face_unlock_rounded : Icons.verified_rounded,
            color: isEscalated ? AppColors.escalate : AppColors.allow,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notice,
              style: AppTextStyles.xs(
                context,
                color: isEscalated ? AppColors.escalate : AppColors.allow,
                fontWeight: AppTextStyles.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.block.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.block.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.block,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.xs(context, color: AppColors.block),
            ),
          ),
        ],
      ),
    );
  }

  // --- Section 1: Connected Accounts ---
  Widget _buildConnectedAccountsSection(
    BuildContext context,
    BillsState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected Enterprise Accounts',
                    style: AppTextStyles.md(
                      context,
                      fontWeight: AppTextStyles.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Identity and Billing IDs bound to this Treasury Safe',
                    style: AppTextStyles.mono(
                      context,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _showConnectAccountSheet(context),
              icon: const Icon(
                Icons.add_link_rounded,
                size: 16,
                color: AppColors.brandPrimary,
              ),
              label: Text(
                'Link Account',
                style: AppTextStyles.xs(
                  context,
                  color: AppColors.brandPrimary,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.accounts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurfacePure,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Enterprise Accounts Linked',
                        style: AppTextStyles.sm(
                          context,
                          fontWeight: AppTextStyles.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Link Google Cloud, AWS, or Alchemy billing to automate corporate x402 settlements.',
                        style: AppTextStyles.xs(
                          context,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.accounts.length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final acc = state.accounts[index];
                return _buildAccountCard(context, acc);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, ConnectedAccount acc) {
    IconData icon;
    Color iconColor;

    switch (acc.provider) {
      case 'google_cloud':
        icon = Icons.cloud_done_rounded;
        iconColor = Colors.blueAccent;
        break;
      case 'aws':
        icon = Icons.cloud_queue_rounded;
        iconColor = Colors.orangeAccent;
        break;
      case 'alchemy':
        icon = Icons.hub_rounded;
        iconColor = AppColors.brandPrimary;
        break;
      default:
        icon = Icons.business_rounded;
        iconColor = Colors.purpleAccent;
    }

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  acc.name,
                  style: AppTextStyles.xs(
                    context,
                    fontWeight: AppTextStyles.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: acc.isConnected
                      ? AppColors.allowBackground
                      : AppColors.blockBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  acc.isConnected ? 'LINKED' : 'OFFLINE',
                  style: AppTextStyles.mono(
                    context,
                    fontSize: 9,
                    color: acc.isConnected
                        ? AppColors.allowText
                        : AppColors.blockText,
                    fontWeight: AppTextStyles.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            acc.accountId,
            style: AppTextStyles.mono(
              context,
              fontSize: 10,
              color: AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${acc.projects.length} Projects',
                style: AppTextStyles.xs(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Safe Bound',
                style: AppTextStyles.mono(
                  context,
                  fontSize: 10,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Section 2: Invoices & x402 Bills ---
  Widget _buildBillsSection(BuildContext context, BillsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company Invoices & x402 Paywalls',
                    style: AppTextStyles.md(
                      context,
                      fontWeight: AppTextStyles.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'HTTP 402 challenges settled via Chapter 2 Guardian & Safe Multisig',
                    style: AppTextStyles.mono(
                      context,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.actionPillBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.actionPillBorder),
              ),
              child: Text(
                '${state.bills.length} Invoices',
                style: AppTextStyles.xs(context, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (state.bills.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurfacePure,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Pending Invoices',
                        style: AppTextStyles.sm(
                          context,
                          fontWeight: AppTextStyles.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All corporate paywalls are settled. Incoming x402 payment demands will appear here.',
                        style: AppTextStyles.xs(
                          context,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.bills.length,
            separatorBuilder: (_, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final bill = state.bills[index];
              return _buildBillCard(context, bill, state);
            },
          ),
      ],
    );
  }

  Widget _buildBillCard(
    BuildContext context,
    CompanyBill bill,
    BillsState state,
  ) {
    final isSettled = bill.isSettled;
    final isPaying = state.isPayingBill && state.payingBillId == bill.id;
    final exceedsDailyCap = bill.amountUsdc > 500;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurfacePure,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSettled
              ? AppColors.allow.withValues(alpha: 0.5)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSettled
                      ? AppColors.allow.withValues(alpha: 0.12)
                      : (exceedsDailyCap
                            ? AppColors.escalate.withValues(alpha: 0.12)
                            : AppColors.brandPrimary.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSettled
                      ? Icons.check_circle_rounded
                      : (exceedsDailyCap
                            ? Icons.shield_rounded
                            : Icons.bolt_rounded),
                  color: isSettled
                      ? AppColors.allow
                      : (exceedsDailyCap
                            ? AppColors.escalate
                            : AppColors.brandPrimary),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.serviceName,
                      style: AppTextStyles.md(
                        context,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Account: ${bill.accountId}',
                      style: AppTextStyles.mono(
                        context,
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${bill.amountUsdc.toStringAsFixed(2)}',
                    style: AppTextStyles.xl(
                      context,
                      color: isSettled ? AppColors.allow : Colors.white,
                      fontWeight: AppTextStyles.bold,
                    ),
                  ),
                  Text(
                    'USDC',
                    style: AppTextStyles.mono(
                      context,
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Description
          Text(
            bill.description,
            style: AppTextStyles.xs(context, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          // Invoice details pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          bill.invoiceNumber,
                          style: AppTextStyles.mono(
                            context,
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          bill.paymentIdentifier,
                          style: AppTextStyles.mono(
                            context,
                            fontSize: 10,
                            color: AppColors.brandPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Status and action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (isSettled ? AppColors.allow : AppColors.escalate)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isSettled ? AppColors.allow : AppColors.escalate)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSettled
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded,
                        size: 13,
                        color: isSettled ? AppColors.allow : AppColors.escalate,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isSettled
                              ? 'HTTP 200 UNLOCKED'
                              : 'HTTP 402 REQUIRED',
                          style: AppTextStyles.mono(
                            context,
                            fontSize: 10,
                            color: isSettled
                                ? AppColors.allow
                                : AppColors.escalate,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isSettled) ...[
                OutlinedButton.icon(
                  onPressed: () => _showSettledReceiptSheet(context, bill),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.allow,
                    side: const BorderSide(color: AppColors.allow),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: Text(
                    'Receipt',
                    style: AppTextStyles.xs(context, color: AppColors.allow),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: isPaying
                      ? null
                      : () {
                          final activeAgent =
                              context.read<AuthCubit>().state.agents.isNotEmpty
                              ? context
                                    .read<AuthCubit>()
                                    .state
                                    .agents
                                    .first
                                    .agentId
                              : null;
                          context.read<BillsCubit>().payBill(
                            bill.id,
                            agentAddress: activeAgent,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: exceedsDailyCap
                        ? AppColors.escalate
                        : AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    elevation: 0,
                  ),
                  icon: isPaying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          exceedsDailyCap
                              ? Icons.face_unlock_rounded
                              : Icons.smart_toy_rounded,
                          size: 15,
                        ),
                  label: Text(
                    isPaying
                        ? 'Settling...'
                        : (exceedsDailyCap
                              ? 'Face ID Sign'
                              : 'Dispatch Agent'),
                    style: AppTextStyles.xs(
                      context,
                      color: Colors.white,
                      fontWeight: AppTextStyles.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- Section 3: Bazaar Discovery Catalog ---
  Widget _buildBazaarDiscoverySection(BuildContext context, BillsState state) {
    final displayedResources = state.displayedBazaarResources;
    final categories = ['ALL', 'WEATHER', 'COMPUTE', 'SECURITY', 'RPC'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'x402 Bazaar Service Catalog',
                    style: AppTextStyles.md(
                      context,
                      fontWeight: AppTextStyles.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Discover, choose, and invoke paywall resources via Safe x402',
                    style: AppTextStyles.mono(
                      context,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.actionPillBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.actionPillBorder),
              ),
              child: Text(
                '${displayedResources.length} Available',
                style: AppTextStyles.xs(context, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurfacePure,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => context.read<BillsCubit>().searchBazaar(val),
                  style: AppTextStyles.sm(context, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search services (e.g. 'weather APIs', 'gpu', 'rpc')...",
                    hintStyle: AppTextStyles.xs(context, color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (state.searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    context.read<BillsCubit>().searchBazaar('');
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Category Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = state.selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat == 'ALL' ? 'All Services' : cat,
                    style: AppTextStyles.xs(
                      context,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      fontWeight: isSelected ? AppTextStyles.bold : AppTextStyles.regular,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.brandPrimary,
                  backgroundColor: AppColors.cardSurfacePure,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.brandPrimary : AppColors.cardBorder,
                    ),
                  ),
                  onSelected: (_) => context.read<BillsCubit>().setBazaarCategory(cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Results list or Empty State
        if (displayedResources.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardSurfacePure,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'No Bazaar services found',
                  style: AppTextStyles.sm(
                    context,
                    color: Colors.white70,
                    fontWeight: AppTextStyles.semiBold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try searching for "weather APIs", "gpu", or "rpc"',
                  style: AppTextStyles.xs(context, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    context.read<BillsCubit>().searchBazaar('');
                    context.read<BillsCubit>().setBazaarCategory('ALL');
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text('Reset Filters', style: AppTextStyles.xs(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    side: const BorderSide(color: AppColors.brandPrimary),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedResources.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final resource = displayedResources[index];
              return InkWell(
                onTap: () => _showBazaarServiceSheet(context, resource),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurfacePure,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (resource.method == 'GET'
                                      ? AppColors.allow
                                      : AppColors.brandPrimary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              resource.method,
                              style: AppTextStyles.mono(
                                context,
                                fontSize: 9,
                                color: resource.method == 'GET'
                                    ? AppColors.allow
                                    : AppColors.brandPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resource.serviceName,
                              style: AppTextStyles.sm(
                                context,
                                fontWeight: AppTextStyles.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${resource.priceUsdc.toStringAsFixed(2)} USDC',
                              style: AppTextStyles.mono(
                                context,
                                fontSize: 11,
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resource.description,
                        style: AppTextStyles.xs(context, color: Colors.white60),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: resource.tags.take(3).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSurface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: AppTextStyles.mono(
                                      context,
                                      fontSize: 9,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _showBazaarServiceSheet(context, resource),
                            icon: const Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: AppColors.brandPrimary,
                            ),
                            label: Text(
                              'Choose & Call',
                              style: AppTextStyles.xs(
                                context,
                                color: AppColors.brandPrimary,
                                fontWeight: AppTextStyles.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showBazaarServiceSheet(BuildContext context, BazaarResource resource) {
    final paramController = TextEditingController(
      text: (resource.queryParams['city'] as String?) ?? 'San Francisco',
    );
    final exceedsLimit = resource.priceUsdc > 500;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return BlocBuilder<BillsCubit, BillsState>(
            builder: (cubitCtx, state) {
              final isInvoking = state.isInvokingService;
              final result = state.lastInvocationResult;
              final hasResult =
                  result != null && result.resourceUrl == resource.resource;

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.screenBackgroundElevated,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resource.serviceName,
                                  style: AppTextStyles.lg(
                                    ctx,
                                    fontWeight: AppTextStyles.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Bazaar Protocol Resource • Safe Multisig',
                                  style: AppTextStyles.mono(
                                    ctx,
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              context.read<BillsCubit>().clearLastInvocation();
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Price & Policy Badge
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (exceedsLimit
                                  ? AppColors.escalate
                                  : AppColors.allow)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (exceedsLimit
                                    ? AppColors.escalate
                                    : AppColors.allow)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              exceedsLimit
                                  ? Icons.shield_rounded
                                  : Icons.verified_user_rounded,
                              color: exceedsLimit
                                  ? AppColors.escalate
                                  : AppColors.allow,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${resource.priceUsdc.toStringAsFixed(2)} USDC per Call',
                                    style: AppTextStyles.sm(
                                      ctx,
                                      color: exceedsLimit
                                          ? AppColors.escalate
                                          : AppColors.allow,
                                      fontWeight: AppTextStyles.bold,
                                    ),
                                  ),
                                  Text(
                                    exceedsLimit
                                        ? 'Exceeds autonomous cap (\$500). Biometric Face ID sign-off required.'
                                        : 'Within Safe autonomous limit (\$500). Evaluates as ALLOW.',
                                    style: AppTextStyles.mono(
                                      ctx,
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Service Description
                      Text(
                        resource.description,
                        style: AppTextStyles.xs(ctx, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      // Schema metadata pill
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfacePure,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resource Endpoint URL',
                              style: AppTextStyles.xs(
                                ctx,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    resource.resource,
                                    style: AppTextStyles.mono(
                                      ctx,
                                      fontSize: 11,
                                      color: AppColors.brandPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: resource.resource),
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Endpoint URL copied!'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Parameters
                            if (resource.queryParams.isNotEmpty) ...[
                              Text(
                                'Bazaar Input Parameter (e.g. city)',
                                style: AppTextStyles.xs(
                                  ctx,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: paramController,
                                style: AppTextStyles.sm(
                                  ctx,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.cardSurface,
                                  hintText:
                                      'Enter query parameter (e.g. San Francisco)',
                                  hintStyle: AppTextStyles.xs(
                                    ctx,
                                    color: AppColors.textMuted,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: AppColors.cardBorder,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Call Action Button
                      ElevatedButton.icon(
                        onPressed: isInvoking
                            ? null
                            : () {
                                final activeAgent = context
                                        .read<AuthCubit>()
                                        .state
                                        .agents
                                        .isNotEmpty
                                    ? context
                                          .read<AuthCubit>()
                                          .state
                                          .agents
                                          .first
                                          .agentId
                                    : null;
                                final queryMap = Map<String, dynamic>.from(
                                  resource.queryParams,
                                );
                                if (queryMap.containsKey('city')) {
                                  queryMap['city'] =
                                      paramController.text.trim();
                                }
                                context.read<BillsCubit>().invokeBazaarService(
                                  resource,
                                  params: queryMap,
                                  agentAddress: activeAgent,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: exceedsLimit
                              ? AppColors.escalate
                              : AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: isInvoking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                exceedsLimit
                                    ? Icons.face_unlock_rounded
                                    : Icons.bolt_rounded,
                                size: 18,
                              ),
                        label: Text(
                          isInvoking
                              ? 'Settling on-chain & Invoking...'
                              : (exceedsLimit
                                    ? 'Face ID Sign-Off & Call (\$${resource.priceUsdc.toStringAsFixed(0)})'
                                    : 'Call Service (x402 \$${resource.priceUsdc.toStringAsFixed(2)})'),
                          style: AppTextStyles.sm(
                            ctx,
                            color: Colors.white,
                            fontWeight: AppTextStyles.bold,
                          ),
                        ),
                      ),
                      // Live Result View if present
                      if (hasResult) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurfacePure,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.allow),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.allow,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'HTTP 200 SUCCESSFUL INVOCATION',
                                    style: AppTextStyles.mono(
                                      ctx,
                                      fontSize: 11,
                                      color: AppColors.allow,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (result.txHash != null &&
                                  result.txHash!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Settlement Tx (Base Sepolia):',
                                  style: AppTextStyles.xs(
                                    ctx,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        result.txHash!,
                                        style: AppTextStyles.mono(
                                          ctx,
                                          fontSize: 10,
                                          color: AppColors.brandPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: result.txHash!),
                                        );
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Settlement hash copied!',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Service Response Payload:',
                                style: AppTextStyles.xs(
                                  ctx,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  result.data != null
                                      ? result.data!.entries
                                            .map((e) => '${e.key}: ${e.value}')
                                            .join('\n')
                                      : 'No data returned',
                                  style: AppTextStyles.mono(
                                    ctx,
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Modals & Sheets ---
  void _showConnectAccountSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String provider = 'google_cloud';
    String name = 'Google Cloud Platform (GCP)';
    String organization = 'Acme Global Enterprises Inc.';
    String accountId = 'billingAccounts/01A2B3-456C7D-89EF01';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Link Corporate Account',
                          style: AppTextStyles.lg(
                            ctx,
                            fontWeight: AppTextStyles.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Binds Organization & Billing Account to the Chapter 2 Safe Mandate',
                    style: AppTextStyles.xs(ctx, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: provider,
                    dropdownColor: AppColors.cardSurfacePure,
                    decoration: InputDecoration(
                      labelText: 'Cloud / Service Provider',
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'google_cloud',
                        child: Text('Google Cloud Platform (GCP)'),
                      ),
                      DropdownMenuItem(
                        value: 'aws',
                        child: Text('Amazon Web Services (AWS)'),
                      ),
                      DropdownMenuItem(
                        value: 'alchemy',
                        child: Text('Alchemy Supernode'),
                      ),
                      DropdownMenuItem(
                        value: 'openai',
                        child: Text('OpenAI Platform'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          provider = val;
                          if (val == 'google_cloud') {
                            name = 'Google Cloud Platform (GCP)';
                            accountId = 'billingAccounts/01A2B3-456C7D-89EF01';
                          } else if (val == 'aws') {
                            name = 'Amazon Web Services (AWS)';
                            accountId = '129384918231';
                          } else if (val == 'alchemy') {
                            name = 'Alchemy Supernode';
                            accountId = 'alc_team_acme_2026';
                          } else {
                            name = 'OpenAI Platform';
                            accountId = 'org-acme-prod-2026';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: organization,
                    decoration: InputDecoration(
                      labelText: 'Corporate Organization',
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (val) => organization = val,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: accountId,
                    decoration: InputDecoration(
                      labelText: 'Billing Account ID / Project ID',
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (val) => accountId = val,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<BillsCubit>().connectAccount(
                        provider: provider,
                        name: name,
                        organization: organization,
                        accountId: accountId,
                        projects: ['production-env', 'data-lake'],
                      );
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.link_rounded),
                    label: Text(
                      'Authorize & Bind Account',
                      style: AppTextStyles.md(
                        ctx,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSettledReceiptSheet(BuildContext context, CompanyBill bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.screenBackgroundElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.allow,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified On-Chain Receipt',
                        style: AppTextStyles.lg(
                          ctx,
                          fontWeight: AppTextStyles.bold,
                        ),
                      ),
                      Text(
                        'Invoice ${bill.invoiceNumber} Settled via Safe Multisig',
                        style: AppTextStyles.mono(
                          ctx,
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurfacePure,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Hash (Base Sepolia)',
                    style: AppTextStyles.xs(ctx, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (bill.txHash != null && bill.txHash!.isNotEmpty)
                              ? bill.txHash!
                              : 'Pending on-chain receipt',
                          style: AppTextStyles.mono(
                            ctx,
                            fontSize: 11,
                            color:
                                (bill.txHash != null && bill.txHash!.isNotEmpty)
                                    ? AppColors.brandPrimary
                                    : AppColors.textMuted,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        onPressed:
                            (bill.txHash != null && bill.txHash!.isNotEmpty)
                                ? () {
                                    Clipboard.setData(
                                      ClipboardData(text: bill.txHash!),
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Transaction hash copied!'),
                                      ),
                                    );
                                  }
                                : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurfacePure,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Identifier & Account Attributed',
                    style: AppTextStyles.xs(ctx, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Identifier: ${bill.paymentIdentifier}',
                    style: AppTextStyles.mono(
                      ctx,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Account: ${bill.accountId}',
                    style: AppTextStyles.mono(
                      ctx,
                      fontSize: 10,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Close Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBiometricApprovalSheet(
    BuildContext context,
    TreasuryAction action,
  ) {
    final authUser = context.read<AuthCubit>().state.user;
    final walletAddress = authUser?.walletAddress ?? '';

    final payload = Eip712ApprovalPayload(
      actionId: action.actionId,
      agentAddress: action.agentAddress,
      recipientAddress: action.recipientAddress,
      tokenAddress: action.tokenAddress,
      amountUnits: action.amountUnits,
      nonce: action.nonce ?? 0,
      deadline: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      mandateHash:
          '0x0000000000000000000000000000000000000000000000000000000000000000',
      riskScore: action.riskScore,
    );

    context.read<ApprovalCubit>().initializeApproval(payload);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BlocConsumer<ApprovalCubit, ApprovalState>(
          listener: (dialogCtx, approvalState) {
            if (approvalState.status == ApprovalStepStatus.approvedSuccess) {
              Navigator.of(sheetContext).pop();
              context.read<BillsCubit>().clearPendingEscalation();
              context.read<BillsCubit>().loadAll();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Invoice #${action.actionId} clear-signed and settled on-chain!',
                  ),
                  backgroundColor: AppColors.allow,
                ),
              );
            }
          },
          builder: (dialogCtx, approvalState) {
            final isSigning =
                approvalState.status == ApprovalStepStatus.signing;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.screenBackgroundElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.face_unlock_rounded,
                        color: AppColors.escalate,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Face ID Biometric Sign-Off',
                              style: AppTextStyles.lg(
                                dialogCtx,
                                fontWeight: AppTextStyles.bold,
                              ),
                            ),
                            Text(
                              'Invoice exceeds autonomous budget limit (\$500)',
                              style: AppTextStyles.mono(
                                dialogCtx,
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurfacePure,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Justification',
                          style: AppTextStyles.xs(
                            dialogCtx,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action.purpose,
                          style: AppTextStyles.sm(
                            dialogCtx,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount Required:',
                              style: AppTextStyles.xs(
                                dialogCtx,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                              style: AppTextStyles.md(
                                dialogCtx,
                                color: AppColors.escalate,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: isSigning
                        ? null
                        : () => dialogCtx
                              .read<ApprovalCubit>()
                              .approveWithPrivyBiometrics(
                                walletAddress: walletAddress,
                                signature:
                                    '0x_privy_biometric_signature_placeholder',
                              ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.escalate,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: isSigning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      isSigning
                          ? 'Authorizing...'
                          : 'Authorize with Biometrics (Passkey)',
                      style: AppTextStyles.md(
                        dialogCtx,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
