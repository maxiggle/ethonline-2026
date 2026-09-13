import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_state.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

final _agentAddressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

/// Three real onboarding steps: what Chapter 2 does, binding a real agent
/// address, and connecting the human's Ledger approver. Nothing here is
/// simulated: every state shown was either returned by the backend or
/// achieved in this session.
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

  // Step 2: bind agent
  late final TextEditingController _agentNameController;
  late final TextEditingController _agentAddressController;
  bool _isLoadingMandate = false;
  String? _mandateError;
  String? _safeAddress;
  String? _guardAddress;
  String? _addressFieldError;
  bool _isBindingAgent = false;
  String? _bindError;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: _currentStep);
    _agentNameController = TextEditingController(text: 'Autonomous Treasury Agent');
    _agentAddressController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentStep == 1) _loadMandate();
      if (_currentStep == 2) context.read<X402ApprovalsCubit>().loadConfig();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _agentNameController.dispose();
    _agentAddressController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (step == 1 && _safeAddress == null && !_isLoadingMandate) _loadMandate();
    if (step == 2) context.read<X402ApprovalsCubit>().loadConfig();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  Future<void> _loadMandate() async {
    setState(() {
      _isLoadingMandate = true;
      _mandateError = null;
    });
    try {
      final mandate = await locator<Chapter2ApiService>().fetchMandate();
      if (!mounted) return;
      setState(() {
        _isLoadingMandate = false;
        _safeAddress = mandate.safeAddress;
        _guardAddress = mandate.guardAddress;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMandate = false;
        _mandateError = e.toString();
      });
    }
  }

  Future<void> _bindAgentAndContinue() async {
    final address = _agentAddressController.text.trim();
    if (!_agentAddressPattern.hasMatch(address)) {
      setState(() => _addressFieldError = 'Enter a valid 0x-prefixed 40-character address');
      return;
    }
    final safeAddress = _safeAddress;
    final guardAddress = _guardAddress;
    if (safeAddress == null || guardAddress == null) return;

    setState(() {
      _addressFieldError = null;
      _bindError = null;
      _isBindingAgent = true;
    });

    try {
      await locator<AuthService>().bindAgent(
        agentAddress: address,
        name: _agentNameController.text.trim().isEmpty
            ? 'Autonomous Treasury Agent'
            : _agentNameController.text.trim(),
        purpose: 'Supervised treasury execution and automated operational disbursements',
        safeAddress: safeAddress,
        guardAddress: guardAddress,
      );
      if (!mounted) return;
      await context.read<AuthCubit>().refreshAgents();
      if (!mounted) return;
      setState(() => _isBindingAgent = false);
      _goToStep(2);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBindingAgent = false;
        _bindError = e.toString();
      });
    }
  }

  void _completeOnboarding() {
    context.router.replaceAll([MainShellRoute()]);
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = ['Welcome', 'Bind Agent', 'Connect Ledger'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: _previousStep,
              )
            : null,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'STEP ${_currentStep + 1} OF 3 · ${stepLabels[_currentStep]}',
            style: AppTextStyles.xs(context, color: AppColors.primary, fontWeight: AppTextStyles.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Welcome(context),
                  _buildStep2BindAgent(context),
                  _buildStep3ConnectLedger(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1 — WELCOME
  // ==========================================
  Widget _buildStep1Welcome(BuildContext context) {
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
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(Icons.shield_rounded, size: 36, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your agent can act. You stay in control.',
            textAlign: TextAlign.center,
            style: AppTextStyles.xl(context, fontWeight: AppTextStyles.bold),
          ),
          const SizedBox(height: 24),
          _buildWelcomePoint(
            context,
            icon: Icons.bolt_rounded,
            title: 'Agents pay for APIs with x402',
            body: 'Your autonomous agent settles real x402 payments in USDC on Base Sepolia.',
          ),
          const SizedBox(height: 14),
          _buildWelcomePoint(
            context,
            icon: Icons.security_rounded,
            title: 'The Guardian decides ALLOW / ESCALATE / BLOCK',
            body: 'Every payment is evaluated against your mandate before it settles.',
          ),
          const SizedBox(height: 14),
          _buildWelcomePoint(
            context,
            icon: Icons.fingerprint_rounded,
            title: 'Big payments are approved on your Ledger',
            body: 'Escalated payments wait for a signature from your hardware wallet.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePoint(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2 — BIND YOUR AGENT
  // ==========================================
  Widget _buildStep2BindAgent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'Bind your agent',
            textAlign: TextAlign.center,
            style: AppTextStyles.xl(context, fontWeight: AppTextStyles.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste the address printed by `npm --prefix scripts run agent:address`. '
            'This is never your Privy wallet.',
            textAlign: TextAlign.center,
            style: AppTextStyles.sm(context, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (_isLoadingMandate)
            _buildCenteredLoading(context, 'Loading Safe and Guard addresses...')
          else if (_mandateError != null)
            _buildMandateError(context)
          else
            _buildBindForm(context),
          const SizedBox(height: 20),
          Text(
            "Only approving escalated payments on a Ledger? You don't need an agent.",
            textAlign: TextAlign.center,
            style: AppTextStyles.sm(context, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _isBindingAgent ? null : () => _goToStep(2),
            child: const Text("Skip, I'm only approving"),
          ),
        ],
      ),
    );
  }

  Widget _buildMandateError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load the active mandate',
            style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
          ),
          const SizedBox(height: 6),
          Text(_mandateError!, style: AppTextStyles.sm(context, color: AppColors.blockText)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _loadMandate, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBindForm(BuildContext context) {
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
          Text('AGENT NAME', style: AppTextStyles.xs(context, fontWeight: AppTextStyles.bold)),
          const SizedBox(height: 8),
          TextField(controller: _agentNameController),
          const SizedBox(height: 16),
          Text('AGENT WALLET ADDRESS', style: AppTextStyles.xs(context, fontWeight: AppTextStyles.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _agentAddressController,
            style: AppTextStyles.mono(context, fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '0x...',
              errorText: _addressFieldError,
            ),
            onChanged: (_) {
              if (_addressFieldError != null) setState(() => _addressFieldError = null);
            },
          ),
          const Divider(height: 28, color: AppColors.border),
          _buildDetailRow('Safe address', _safeAddress ?? ''),
          const SizedBox(height: 6),
          _buildDetailRow('Guard address', _guardAddress ?? ''),
          if (_bindError != null) ...[
            const SizedBox(height: 14),
            Text(_bindError!, style: AppTextStyles.sm(context, color: AppColors.blockText)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isBindingAgent ? null : _bindAgentAndContinue,
              child: _isBindingAgent
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Bind agent'),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3 — CONNECT YOUR LEDGER APPROVER
  // ==========================================
  Widget _buildStep3ConnectLedger(BuildContext context) {
    return BlocBuilder<X402ApprovalsCubit, X402ApprovalsState>(
      builder: (context, state) {
        final isConnected = state.connectedAddress != null;
        final isReady = isConnected && state.matchesApprover;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Connect your Ledger approver',
                textAlign: TextAlign.center,
                style: AppTextStyles.xl(context, fontWeight: AppTextStyles.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Escalated payments are signed on your Ledger. Enable Blind signing in the '
                'Ethereum app\'s settings before connecting.',
                textAlign: TextAlign.center,
                style: AppTextStyles.sm(context, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.usb_rounded,
                          color: isConnected ? (isReady ? AppColors.allow : AppColors.block) : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isConnected ? 'Ledger connected' : 'No Ledger connected',
                            style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.status == X402ApprovalsStatus.connecting
                            ? null
                            : () => _openDeviceScanSheet(context),
                        icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
                        label: Text(isConnected ? 'Reconnect' : 'Connect Ledger'),
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 10),
                      Text(state.connectedAddress!, style: AppTextStyles.mono(context, fontSize: 12)),
                      const SizedBox(height: 8),
                      if (isReady)
                        Text(
                          'Matches the configured approver.',
                          style: AppTextStyles.sm(context, color: AppColors.allowText),
                        )
                      else
                        Text(
                          'This Ledger does not match the configured approver'
                          '${state.config != null ? ' (${state.config!.approverAddress})' : ''}.',
                          style: AppTextStyles.sm(context, color: AppColors.blockText),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: isReady
                    ? ElevatedButton(
                        onPressed: _completeOnboarding,
                        child: const Text('Finish'),
                      )
                    : OutlinedButton(
                        onPressed: _completeOnboarding,
                        child: const Text("I'll connect later"),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDeviceScanSheet(BuildContext context) {
    final cubit = context.read<X402ApprovalsCubit>();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nearby Ledger devices', style: AppTextStyles.lg(sheetContext, fontWeight: AppTextStyles.bold)),
                const SizedBox(height: 4),
                Text(
                  'Unlock your Ledger and open the Ethereum app before connecting.',
                  style: AppTextStyles.sm(sheetContext),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _OnboardingLedgerDeviceList(
                    stream: cubit.scanForDevices(),
                    onDeviceTapped: (device) async {
                      Navigator.of(sheetContext).pop();
                      await cubit.stopScanning();
                      await cubit.connectLedger(device);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => cubit.stopScanning());
  }

  Widget _buildCenteredLoading(BuildContext context, String label) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(label, style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.xs(context, color: AppColors.textMuted)),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.mono(context, fontSize: 11),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _OnboardingLedgerDeviceList extends StatefulWidget {
  const _OnboardingLedgerDeviceList({required this.stream, required this.onDeviceTapped});

  final Stream<LedgerDevice> stream;
  final ValueChanged<LedgerDevice> onDeviceTapped;

  @override
  State<_OnboardingLedgerDeviceList> createState() => _OnboardingLedgerDeviceListState();
}

class _OnboardingLedgerDeviceListState extends State<_OnboardingLedgerDeviceList> {
  final List<LedgerDevice> _devices = [];
  late final StreamSubscription<LedgerDevice> _subscription;
  Object? _scanError;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(
      (device) {
        setState(() {
          if (!_devices.any((existing) => existing.id == device.id)) _devices.add(device);
        });
      },
      onError: (Object error) => setState(() => _scanError = error),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scanError != null) {
      return Center(
        child: Text(
          'Bluetooth scan failed: $_scanError',
          style: AppTextStyles.sm(context, color: AppColors.blockText),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      itemCount: _devices.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth_rounded, color: AppColors.ledgerOrange),
          title: Text(device.name.isNotEmpty ? device.name : device.id),
          subtitle: Text(device.id, style: AppTextStyles.mono(context, fontSize: 10)),
          onTap: () => widget.onDeviceTapped(device),
        );
      },
    );
  }
}
