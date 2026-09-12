import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/guardian_alert/view/guardian_analysis_sheet.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

enum ActivityFilter { all, allowed, escalated, blocked }

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  ActivityFilter _currentFilter = ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: Text(
          'Activity & Verdict Feed',
          style: AppTextStyles.xl(context, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Activity Feed',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () =>
                context.read<DashboardCubit>().loadDashboardMetrics(),
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final allActions = state.recentActions;
          final filteredActions = _filterActions(allActions);

          return RefreshIndicator(
            color: AppColors.brandPrimary,
            backgroundColor: AppColors.cardSurfacePure,
            onRefresh: () async {
              await context.read<DashboardCubit>().loadDashboardMetrics();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'All Events',
                        ActivityFilter.all,
                        allActions.length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Allowed',
                        ActivityFilter.allowed,
                        allActions
                            .where(
                              (a) =>
                                  a.status == TreasuryActionStatus.executed ||
                                  a.status == TreasuryActionStatus.approved,
                            )
                            .length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Escalated',
                        ActivityFilter.escalated,
                        allActions
                            .where(
                              (a) => a.status == TreasuryActionStatus.pending,
                            )
                            .length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Blocked',
                        ActivityFilter.blocked,
                        allActions
                            .where(
                              (a) => a.status == TreasuryActionStatus.rejected,
                            )
                            .length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (filteredActions.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurfacePure,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Events Found',
                          style: AppTextStyles.lg(
                            context,
                            fontWeight: AppTextStyles.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transactions matching this filter will appear here live.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sm(context),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredActions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildActionCard(context, action),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<TreasuryAction> _filterActions(List<TreasuryAction> actions) {
    switch (_currentFilter) {
      case ActivityFilter.all:
        return actions;
      case ActivityFilter.allowed:
        return actions
            .where(
              (a) =>
                  a.status == TreasuryActionStatus.executed ||
                  a.status == TreasuryActionStatus.approved,
            )
            .toList();
      case ActivityFilter.escalated:
        return actions
            .where((a) => a.status == TreasuryActionStatus.pending)
            .toList();
      case ActivityFilter.blocked:
        return actions
            .where((a) => a.status == TreasuryActionStatus.rejected)
            .toList();
    }
  }

  Widget _buildFilterChip(String label, ActivityFilter filter, int count) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.sm(
              context,
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected
                  ? AppTextStyles.bold
                  : AppTextStyles.medium,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppColors.cardBorder,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.xs(
                context,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      selectedColor: AppColors.actionPillBackground,
      backgroundColor: AppColors.cardSurfacePure,
      side: BorderSide(
        color: isSelected
            ? AppColors.actionPillBackground
            : AppColors.cardBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _currentFilter = filter),
    );
  }

  Widget _buildActionCard(BuildContext context, TreasuryAction action) {
    final isAllow =
        action.status == TreasuryActionStatus.executed ||
        action.status == TreasuryActionStatus.approved;
    final isEscalate = action.status == TreasuryActionStatus.pending;

    final badgeColor = isAllow
        ? AppColors.allow
        : (isEscalate ? AppColors.escalate : AppColors.block);
    final badgeBg = isAllow
        ? AppColors.allowBackground
        : (isEscalate
              ? AppColors.escalateBackground
              : AppColors.blockBackground);
    final badgeText = isAllow
        ? AppColors.allowText
        : (isEscalate ? AppColors.escalateText : AppColors.blockText);
    final badgeLabel = isAllow ? 'ALLOW' : (isEscalate ? 'ESCALATE' : 'BLOCK');

    return InkWell(
      onTap: () => GuardianAnalysisSheet.show(context, action),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurfacePure,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: Icon(
                isAllow
                    ? Icons.arrow_outward_rounded
                    : (isEscalate
                          ? Icons.fingerprint_rounded
                          : Icons.shield_rounded),
                color: badgeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.purpose.isNotEmpty
                        ? action.purpose
                        : 'Autonomous Transfer',
                    style: AppTextStyles.md(
                      context,
                      fontWeight: AppTextStyles.semiBold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Target: ${action.recipientAddress.length > 14 ? '${action.recipientAddress.substring(0, 6)}...${action.recipientAddress.substring(action.recipientAddress.length - 4)}' : action.recipientAddress}',
                    style: AppTextStyles.mono(
                      context,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-\$${action.amountDisplayUsdc.toStringAsFixed(2)}',
                  style: AppTextStyles.md(
                    context,
                    fontWeight: AppTextStyles.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: AppTextStyles.xs(
                      context,
                      color: badgeText,
                      fontWeight: AppTextStyles.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
