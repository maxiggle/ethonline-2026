import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isAuthenticated) {
            onLoginSuccess?.call();
            if (state.isNewUser) {
              context.router.replace(OnboardingRoute());
            } else {
              context.read<DashboardCubit>().loadDashboardMetrics();
              context.router.replace(DashboardRoute());
            }
          }
          if (state.status == AuthStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage!,
                  style: AppTextStyles.sm(context, color: Colors.white),
                ),
                backgroundColor: AppColors.block,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state.status == AuthStatus.loading;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.actionPillBackground,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.actionPillBorder,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 38,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Product Title & Principle
                    Text(
                      'CHAPTER 2',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.xxl(
                        context,
                        color: Colors.white,
                        fontWeight: AppTextStyles.extraBold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your agents can act. You stay in control.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.md(
                        context,
                        color: AppColors.textLightMuted,
                        fontWeight: AppTextStyles.medium,
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Screen 1 Authority Node Diagram: Agent -> Guardian -> Human Authority
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.actionPillBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.actionPillBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildNode(
                                context,
                                icon: Icons.smart_toy_rounded,
                                title: 'AI Agent',
                                subtitle: 'Acts',
                                color: AppColors.brandPrimary,
                              ),
                              _buildConnector(),
                              _buildNode(
                                context,
                                icon: Icons.security_rounded,
                                title: 'Guardian',
                                subtitle: 'Evaluates',
                                color: AppColors.escalate,
                              ),
                              _buildConnector(),
                              _buildNode(
                                context,
                                icon: Icons.fingerprint_rounded,
                                title: 'Human',
                                subtitle: 'Authorizes',
                                color: AppColors.allow,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Autonomous micro-actions execute under Chapter2Guard.\nHigh-risk escalations require human clear-signing.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.xs(
                              context,
                              color: AppColors.textLightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Single Primary CTA: Sign In with Privy
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => context.read<AuthCubit>().loginWithGoogle(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.screenBackground,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.screenBackground,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.login_rounded,
                                    size: 20,
                                    color: AppColors.screenBackground,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Sign In with Privy',
                                    style: AppTextStyles.md(
                                      context,
                                      color: AppColors.screenBackground,
                                      fontWeight: AppTextStyles.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                await context.read<AuthCubit>().logout();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cached Privy session cleared from device.',
                                        style: AppTextStyles.sm(
                                          context,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor:
                                          AppColors.actionPillBackground,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: AppColors.textLightMuted,
                        ),
                        label: Text(
                          'Reset Cached Session',
                          style: AppTextStyles.xs(
                            context,
                            color: AppColors.textLightMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          context.router.push(OnboardingRoute());
                        },
                        child: Text(
                          'Learn how it works',
                          style: AppTextStyles.xs(
                            context,
                            color: AppColors.brandPrimary,
                            fontWeight: AppTextStyles.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Autonomous Treasury Supervision on Base Sepolia\nPowered by Privy EVM Wallets & Gnosis Safe',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.xs(
                        context,
                        color: AppColors.textLightMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNode(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyles.xs(
              context,
              color: Colors.white,
              fontWeight: AppTextStyles.bold,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.xs(
              context,
              color: color,
              fontWeight: AppTextStyles.medium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector() {
    return SizedBox(
      width: 20,
      child: Divider(color: AppColors.actionPillBorder, thickness: 1.5),
    );
  }
}
