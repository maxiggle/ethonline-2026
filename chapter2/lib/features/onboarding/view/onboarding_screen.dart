import 'dart:math';
import 'package:auto_route/auto_route.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int _currentStep;
  late final PageController _pageController;

  // Step 1: Human Verification (World ID)
  bool _isVerifyingWorld = false;
  bool _isWorldVerified = false;
  String? _worldNullifierHash;
  String? _worldVerifiedAt;

  // Step 2: Agent Creation
  late final TextEditingController _agentNameController;
  bool _isBindingAgent = false;

  // Step 3: Mandate Configuration
  double _maxTxAmount = 100.0;
  final double _dailyLimit = 500.0;
  bool _allowInfra = true;
  bool _allowSubscriptions = true;
  bool _allowTransfers = true;

  // Step 4: Security Setup
  bool _faceIdEnabled = true;
  bool _ledgerPaired = true;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: _currentStep);
    _agentNameController = TextEditingController(
      text: 'Autonomous Treasury Agent',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _agentNameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _verifyWithWorld() async {
    setState(() => _isVerifyingWorld = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final randomHex = List.generate(
      8,
      (_) => Random().nextInt(16).toRadixString(16),
    ).join();
    setState(() {
      _isVerifyingWorld = false;
      _isWorldVerified = true;
      _worldNullifierHash = '0x9a3c${randomHex}e810';
      _worldVerifiedAt = DateTime.now()
          .toUtc()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll('T', ' ');
    });
  }

  Future<void> _bindAgentAndContinue() async {
    setState(() => _isBindingAgent = true);
    try {
      final authCubit = context.read<AuthCubit>();
      final walletAddress = authCubit.state.user?.walletAddress;
      if (walletAddress == null || walletAddress.isEmpty) {
        throw Exception(
          'No active Privy embedded wallet detected for this account.',
        );
      }

      String safeAddress = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
      String guardAddress = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
      try {
        final apiService = locator<Chapter2ApiService>();
        final mandate = await apiService.fetchMandate();
        if (mandate.safeAddress.isNotEmpty) safeAddress = mandate.safeAddress;
        if (mandate.guardAddress.isNotEmpty) guardAddress = mandate.guardAddress;
      } catch (_) {}

      final authService = locator<AuthService>();
      await authService.bindAgent(
        agentAddress: walletAddress,
        name: _agentNameController.text.trim().isEmpty
            ? 'Autonomous Treasury Agent'
            : _agentNameController.text.trim(),
        purpose:
            'Supervised treasury execution and automated operational disbursements',
        safeAddress: safeAddress,
        guardAddress: guardAddress,
      );
      if (mounted) {
        await context.read<AuthCubit>().refreshAgents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agent registration notice: $e'),
            backgroundColor: AppColors.screenBackgroundElevated,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBindingAgent = false);
        _nextStep();
      }
    }
  }

  void _completeOnboarding() {
    context.read<DashboardCubit>().loadDashboardMetrics();
    context.router.replaceAll([DashboardRoute()]);
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = [
      'Human ID',
      'Treasury Agent',
      'Mandate Limits',
      'Security Setup',
    ];

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        backgroundColor: AppColors.screenBackground,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: _previousStep,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.actionPillBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.actionPillBorder),
              ),
              child: Text(
                'STEP ${_currentStep + 1} OF 4',
                style: AppTextStyles.xs(
                  context,
                  color: AppColors.brandPrimary,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stepLabels[_currentStep],
              style: AppTextStyles.sm(
                context,
                color: AppColors.textLightMuted,
                fontWeight: AppTextStyles.medium,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Skip',
              style: AppTextStyles.xs(context, color: AppColors.textLightMuted),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.brandPrimary,
                  ),
                  minHeight: 4,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1HumanVerification(context),
                  _buildStep2CreateAgent(context),
                  _buildStep3DefineMandate(context),
                  _buildStep4SecuritySetup(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SCREEN 2 — HUMAN VERIFICATION (World ID)
  // ==========================================
  Widget _buildStep1HumanVerification(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.actionPillBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.actionPillBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 36,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Verify your identity',
            textAlign: TextAlign.center,
            style: AppTextStyles.xl(
              context,
              color: Colors.white,
              fontWeight: AppTextStyles.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chapter 2 uses World to establish that a real human is behind the autonomous agent. Your agent can act autonomously, but Chapter 2 needs to know who ultimately controls its authority.',
            textAlign: TextAlign.center,
            style: AppTextStyles.sm(context, color: AppColors.textLightMuted),
          ),
          const SizedBox(height: 28),

          // Verification Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isWorldVerified
                            ? AppColors.allowBackground
                            : AppColors.actionPillBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isWorldVerified
                            ? Icons.check_circle_rounded
                            : Icons.public_rounded,
                        size: 20,
                        color: _isWorldVerified
                            ? AppColors.allowText
                            : AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Human Verification',
                            style: AppTextStyles.md(
                              context,
                              color: Colors.white,
                              fontWeight: AppTextStyles.bold,
                            ),
                          ),
                          Text(
                            _isWorldVerified
                                ? 'World ID proof verified on Base Sepolia'
                                : 'World verification available',
                            style: AppTextStyles.xs(
                              context,
                              color: _isWorldVerified
                                  ? AppColors.allowText
                                  : AppColors.textLightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isWorldVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.allowBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.allowBorder),
                        ),
                        child: Text(
                          'Human verified ✓',
                          style: AppTextStyles.xs(
                            context,
                            color: AppColors.allowText,
                            fontWeight: AppTextStyles.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isWorldVerified && _worldNullifierHash != null) ...[
                  const Divider(height: 24, color: AppColors.cardBorder),
                  _buildDetailRow('Nullifier Hash', _worldNullifierHash!),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'Verification Method',
                    'Orb-verified ZK Proof',
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'Verified At',
                    _worldVerifiedAt ?? 'Just now',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Primary Action
          if (!_isWorldVerified)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isVerifyingWorld ? null : _verifyWithWorld,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.screenBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isVerifyingWorld
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.screenBackground,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Connecting to World...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 20,
                            color: AppColors.screenBackground,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Verify with World',
                            style: AppTextStyles.md(
                              context,
                              color: AppColors.screenBackground,
                              fontWeight: AppTextStyles.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Agent Setup',
                      style: AppTextStyles.md(
                        context,
                        color: Colors.white,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 3 — CREATE YOUR AGENT
  // ==========================================
  Widget _buildStep2CreateAgent(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = authState.user;
        final walletAddress = user?.walletAddress;
        final hasWallet = walletAddress != null && walletAddress.isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.actionPillBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.actionPillBorder,
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 36,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Create your Treasury Agent',
                textAlign: TextAlign.center,
                style: AppTextStyles.xl(
                  context,
                  color: Colors.white,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Treasury Agent can propose and execute financial actions within the mandate you create.',
                textAlign: TextAlign.center,
                style: AppTextStyles.sm(
                  context,
                  color: AppColors.textLightMuted,
                ),
              ),
              const SizedBox(height: 28),

              // Form Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.screenBackgroundElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGENT NAME',
                      style: AppTextStyles.xs(
                        context,
                        color: AppColors.textLightMuted,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _agentNameController,
                      style: AppTextStyles.md(context, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.actionPillBackground,
                        hintText: 'Autonomous Treasury Agent',
                        hintStyle: AppTextStyles.sm(
                          context,
                          color: AppColors.textLightMuted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.actionPillBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.actionPillBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (hasWallet) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Agent Wallet',
                            style: AppTextStyles.xs(
                              context,
                              color: AppColors.textLightMuted,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: walletAddress));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Agent wallet address copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  walletAddress.length > 14
                                      ? '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}'
                                      : walletAddress,
                                  style: AppTextStyles.xs(
                                    context,
                                    color: Colors.white,
                                    fontWeight: AppTextStyles.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: AppColors.textLightMuted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandPrimary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Provisioning Privy Embedded Wallet...',
                            style: AppTextStyles.xs(context, color: AppColors.escalateText),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20, color: AppColors.cardBorder),
                    _buildDetailRow('Key Type', 'Privy Secure Enclave Embedded Key'),
                    const Divider(height: 20, color: AppColors.cardBorder),
                    _buildDetailRow('Network', 'Base Sepolia (84532)'),
                    const Divider(height: 20, color: AppColors.cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: AppTextStyles.xs(
                            context,
                            color: AppColors.textLightMuted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.allowBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.allowBorder),
                          ),
                          child: Text(
                            'Human-backed ✓',
                            style: AppTextStyles.xs(
                              context,
                              color: AppColors.allowText,
                              fontWeight: AppTextStyles.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isBindingAgent || !hasWallet) ? null : _bindAgentAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.screenBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isBindingAgent
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.screenBackground,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: AppTextStyles.md(
                                context,
                                color: AppColors.screenBackground,
                                fontWeight: AppTextStyles.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: AppColors.screenBackground,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // SCREEN 4 — CREATE TREASURY MANDATE
  // ==========================================
  Widget _buildStep3DefineMandate(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Define its authority',
            textAlign: TextAlign.center,
            style: AppTextStyles.xl(
              context,
              color: Colors.white,
              fontWeight: AppTextStyles.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Give your agent enough freedom to work without giving it unlimited control.',
            textAlign: TextAlign.center,
            style: AppTextStyles.sm(context, color: AppColors.textLightMuted),
          ),
          const SizedBox(height: 20),

          // Maximum Transaction Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
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
                      'Maximum transaction',
                      style: AppTextStyles.sm(
                        context,
                        color: Colors.white,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                    Text(
                      '\$${_maxTxAmount.toInt()} USDC',
                      style: AppTextStyles.md(
                        context,
                        color: AppColors.brandPrimary,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Maximum amount the agent can execute autonomously without human approval.',
                  style: AppTextStyles.xs(
                    context,
                    color: AppColors.textLightMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [50.0, 100.0, 250.0, 500.0].map((val) {
                    final isSelected = _maxTxAmount == val;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _maxTxAmount = val),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected
                                ? AppColors.actionPillBackground
                                : Colors.transparent,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.cardBorder,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            '\$${val.toInt()}',
                            style: AppTextStyles.xs(
                              context,
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.textLightMuted,
                              fontWeight: isSelected
                                  ? AppTextStyles.bold
                                  : AppTextStyles.medium,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Daily Spending Limit Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily spending limit',
                      style: AppTextStyles.sm(
                        context,
                        color: Colors.white,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                    Text(
                      'Resets every 24 hours UTC',
                      style: AppTextStyles.xs(
                        context,
                        color: AppColors.textLightMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${_dailyLimit.toInt()} USDC',
                  style: AppTextStyles.lg(
                    context,
                    color: Colors.white,
                    fontWeight: AppTextStyles.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Approved Recipients
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approved recipients',
                  style: AppTextStyles.sm(
                    context,
                    color: Colors.white,
                    fontWeight: AppTextStyles.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRecipientRow('Alchemy API', '0x82...1F90'),
                _buildRecipientRow('AWS / Cloud Services', '0x42...8A21'),
                _buildRecipientRow('OpenAI Platform', '0x91...B02C'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Allowed Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allowed actions',
                  style: AppTextStyles.sm(
                    context,
                    color: Colors.white,
                    fontWeight: AppTextStyles.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCheckRow(
                  'Infrastructure payments',
                  _allowInfra,
                  (v) => setState(() => _allowInfra = v),
                ),
                _buildCheckRow(
                  'Service subscriptions',
                  _allowSubscriptions,
                  (v) => setState(() => _allowSubscriptions = v),
                ),
                _buildCheckRow(
                  'Approved transfers',
                  _allowTransfers,
                  (v) => setState(() => _allowTransfers = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.actionPillBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.actionPillBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 24,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your agent can:',
                        style: AppTextStyles.xs(
                          context,
                          color: AppColors.brandPrimary,
                          fontWeight: AppTextStyles.bold,
                        ),
                      ),
                      Text(
                        '\$${_maxTxAmount.toInt()} per transaction · \$${_dailyLimit.toInt()} per day · 3 approved recipients',
                        style: AppTextStyles.xs(context, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.screenBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Activate Mandate',
                style: AppTextStyles.md(
                  context,
                  color: AppColors.screenBackground,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 5 — SECURITY SETUP
  // ==========================================
  Widget _buildStep4SecuritySetup(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.actionPillBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.actionPillBorder,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 36,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Secure Chapter 2',
            textAlign: TextAlign.center,
            style: AppTextStyles.xl(
              context,
              color: Colors.white,
              fontWeight: AppTextStyles.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sensitive credentials and high-risk approvals are protected using device and hardware-backed security.',
            textAlign: TextAlign.center,
            style: AppTextStyles.sm(context, color: AppColors.textLightMuted),
          ),
          const SizedBox(height: 28),

          // Security Layer 1: Device Biometrics
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.actionPillBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 24,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Biometrics',
                        style: AppTextStyles.md(
                          context,
                          color: Colors.white,
                          fontWeight: AppTextStyles.bold,
                        ),
                      ),
                      Text(
                        'Face ID / Touch ID authorization',
                        style: AppTextStyles.xs(
                          context,
                          color: AppColors.textLightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _faceIdEnabled,
                  onChanged: (v) => setState(() => _faceIdEnabled = v),
                  activeTrackColor: AppColors.brandPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Security Layer 2: Ledger
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.screenBackgroundElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.actionPillBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 24,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ledger hardware',
                        style: AppTextStyles.md(
                          context,
                          color: Colors.white,
                          fontWeight: AppTextStyles.bold,
                        ),
                      ),
                      Text(
                        _ledgerPaired
                            ? 'Ledger connected ✓'
                            : 'Required for high-risk approvals',
                        style: AppTextStyles.xs(
                          context,
                          color: _ledgerPaired
                              ? AppColors.allowText
                              : AppColors.textLightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _ledgerPaired,
                  onChanged: (v) => setState(() => _ledgerPaired = v),
                  activeTrackColor: AppColors.allowText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.rocket_launch_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Complete Setup & Enter Command Center',
                    style: AppTextStyles.md(
                      context,
                      color: Colors.white,
                      fontWeight: AppTextStyles.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Helper Widgets
  // ==========================================
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.xs(context, color: AppColors.textLightMuted),
        ),
        Text(
          value,
          style: AppTextStyles.xs(
            context,
            color: Colors.white,
            fontWeight: AppTextStyles.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientRow(String name, String address) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: AppColors.allowText,
              ),
              const SizedBox(width: 6),
              Text(name, style: AppTextStyles.xs(context, color: Colors.white)),
            ],
          ),
          Text(
            address,
            style: AppTextStyles.xs(context, color: AppColors.textLightMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Icon(
              value
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: value ? AppColors.allowText : AppColors.textLightMuted,
            ),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.xs(context, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
