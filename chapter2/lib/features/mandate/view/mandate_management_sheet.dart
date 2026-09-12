import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MandateManagementSheet extends StatefulWidget {
  const MandateManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<DashboardCubit>()),
          BlocProvider.value(value: context.read<AuthCubit>()),
        ],
        child: const MandateManagementSheet(),
      ),
    );
  }

  @override
  State<MandateManagementSheet> createState() => _MandateManagementSheetState();
}

class _MandateManagementSheetState extends State<MandateManagementSheet> {
  double _singleLimit = 500.0;
  double _dailyLimit = 2000.0;
  bool _isSaving = false;

  final List<String> _whitelistedVendors = [
    'Google Cloud Vertex AI',
    'Alchemy RPC',
    'Amazon Web Services',
    'OpenAI Platform',
  ];

  @override
  void initState() {
    super.initState();
    final metrics = context.read<DashboardCubit>().state.metrics;
    if (metrics != null && metrics.dailyAutonomousCapUsdc > 0) {
      _dailyLimit = metrics.dailyAutonomousCapUsdc;
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() => _isSaving = false);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Policy updated: Single limit \$$_singleLimit USDC, Daily cap \$$_dailyLimit USDC',
          style: AppTextStyles.sm(context, color: Colors.white),
        ),
        backgroundColor: AppColors.allow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurfacePure,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autonomous Mandate Controls',
                        style: AppTextStyles.xl(context),
                      ),
                      Text(
                        'Set on-chain guardrails for Chapter2Guard.sol',
                        style: AppTextStyles.sm(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Single Action Limit Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Single Transaction Ceiling',
                        style: AppTextStyles.md(
                          context,
                          fontWeight: AppTextStyles.semiBold,
                        ),
                      ),
                      Text(
                        '\$${_singleLimit.toStringAsFixed(0)} USDC',
                        style: AppTextStyles.md(
                          context,
                          fontWeight: AppTextStyles.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Actions exceeding this require human Face ID clear-signing',
                    style: AppTextStyles.xs(context),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.brandPrimary,
                      inactiveTrackColor: AppColors.cardBorder,
                      thumbColor: AppColors.brandPrimary,
                      overlayColor: AppColors.brandPrimary.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    child: Slider(
                      value: _singleLimit,
                      min: 50,
                      max: 2000,
                      divisions: 39,
                      onChanged: (val) => setState(() => _singleLimit = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Daily Cumulative Limit Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Cumulative Cap',
                        style: AppTextStyles.md(
                          context,
                          fontWeight: AppTextStyles.semiBold,
                        ),
                      ),
                      Text(
                        '\$${_dailyLimit.toStringAsFixed(0)} USDC',
                        style: AppTextStyles.md(
                          context,
                          fontWeight: AppTextStyles.bold,
                          color: AppColors.allowText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total autonomous burn allowed per 24 hours',
                    style: AppTextStyles.xs(context),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.allow,
                      inactiveTrackColor: AppColors.cardBorder,
                      thumbColor: AppColors.allow,
                      overlayColor: AppColors.allow.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _dailyLimit,
                      min: 200,
                      max: 10000,
                      divisions: 49,
                      onChanged: (val) => setState(() => _dailyLimit = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Whitelisted Vendors
            Text(
              'Approved Vendor Whitelist',
              style: AppTextStyles.sm(
                context,
                fontWeight: AppTextStyles.semiBold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _whitelistedVendors.map((vendor) {
                return Chip(
                  avatar: const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: AppColors.allow,
                  ),
                  label: Text(
                    vendor,
                    style: AppTextStyles.xs(
                      context,
                      color: AppColors.textPrimary,
                      fontWeight: AppTextStyles.medium,
                    ),
                  ),
                  backgroundColor: AppColors.cardSurface,
                  side: const BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Save & Biometric Clear-Sign CTA
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPillBackground,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Update Mandate with Biometrics',
                          style: AppTextStyles.md(
                            context,
                            color: Colors.white,
                            fontWeight: AppTextStyles.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
