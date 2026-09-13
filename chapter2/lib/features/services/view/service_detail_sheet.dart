import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';
import 'package:chapter2/features/services/cubit/services_cubit.dart';
import 'package:chapter2/features/services/cubit/services_state.dart';
import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/x402_approvals/utils/usdc_amount_formatter.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _justificationMaxLength = 280;

/// Opens the service detail sheet: full details, editable inputs prefilled
/// from the catalog, an agent picker, and the "Ask agent to pay" action. On
/// success it closes the sheet, shows a confirmation SnackBar, and opens the
/// purchase detail screen.
Future<void> showServiceDetailSheet(BuildContext context, {required BazaarService service}) async {
  final servicesCubit = context.read<ServicesCubit>();
  final authCubit = context.read<AuthCubit>();

  final result = await showModalBottomSheet<_PurchaseCreationResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => MultiBlocProvider(
      providers: [
        BlocProvider<ServicesCubit>.value(value: servicesCubit),
        BlocProvider<AuthCubit>.value(value: authCubit),
      ],
      child: _ServiceDetailSheetContent(service: service),
    ),
  );

  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sent to ${result.agentName}'), behavior: SnackBarBehavior.floating),
    );
    context.router.push(
      PurchaseDetailRoute(purchaseRequestId: result.request.id, initialPurchase: result.request),
    );
  }
}

class _PurchaseCreationResult {
  const _PurchaseCreationResult({required this.request, required this.agentName});

  final PurchaseRequest request;
  final String agentName;
}

class _ServiceDetailSheetContent extends StatefulWidget {
  const _ServiceDetailSheetContent({required this.service});

  final BazaarService service;

  @override
  State<_ServiceDetailSheetContent> createState() => _ServiceDetailSheetContentState();
}

class _ServiceDetailSheetContentState extends State<_ServiceDetailSheetContent> {
  late final Map<String, TextEditingController> _queryControllers;
  late final TextEditingController _justificationController;
  String? _selectedAgentAddress;
  String? _localValidationError;

  @override
  void initState() {
    super.initState();
    _queryControllers = {
      for (final entry in widget.service.queryParams.entries) entry.key: TextEditingController(text: entry.value),
    };
    _justificationController = TextEditingController(
      text: 'Purchase ${widget.service.serviceName} for company use',
    );
  }

  @override
  void dispose() {
    for (final controller in _queryControllers.values) {
      controller.dispose();
    }
    _justificationController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<AgentModel> agents) async {
    final selectedAddress = _selectedAgentAddress;
    if (selectedAddress == null) {
      setState(() => _localValidationError = 'Choose an agent to pay with.');
      return;
    }
    final justification = _justificationController.text.trim();
    if (justification.isEmpty) {
      setState(() => _localValidationError = 'Add a short justification.');
      return;
    }
    if (justification.length > _justificationMaxLength) {
      setState(() => _localValidationError = 'Justification must be $_justificationMaxLength characters or fewer.');
      return;
    }
    setState(() => _localValidationError = null);

    final selectedAgent = agents.firstWhere((agent) => agent.agentAddress == selectedAddress);
    final queryParams = {
      for (final entry in _queryControllers.entries) entry.key: entry.value.text.trim(),
    };

    final request = await context.read<ServicesCubit>().createPurchaseRequest(
          agentAddress: selectedAgent.agentAddress,
          resourceUrl: widget.service.resourceUrl,
          queryParams: queryParams,
          justification: justification,
        );

    if (request != null && mounted) {
      Navigator.of(context).pop(_PurchaseCreationResult(request: request, agentName: selectedAgent.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final agents = context.watch<AuthCubit>().state.agents;
    final activeAgents = agents.where((agent) => agent.status == 'ACTIVE').toList();
    if (_selectedAgentAddress == null && activeAgents.isNotEmpty) {
      _selectedAgentAddress = activeAgents.first.agentAddress;
    }

    final servicesState = context.watch<ServicesCubit>().state;
    final isSubmitting = servicesState.createStatus == ServicesCreateStatus.submitting;
    final backendError =
        servicesState.createStatus == ServicesCreateStatus.failure ? servicesState.createError : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(service.serviceName, style: AppTextStyles.xl(context, fontWeight: AppTextStyles.bold)),
                const SizedBox(height: 8),
                Text(service.description, style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
                if (service.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final tag in service.tags) _buildTagChip(context, tag)],
                  ),
                ],
                const SizedBox(height: 18),
                _buildDetailRow(context, 'Price', '\$${UsdcAmountFormatter.format(service.priceAtomicUnits)} USDC'),
                _buildDetailRow(context, 'Payee', _shortenAddress(service.payTo), copyValue: service.payTo),
                _buildDetailRow(context, 'Network', service.networkLabel),
                _buildDetailRow(context, 'Method', '${service.method} ${service.resourcePath}'),
                if (service.outputExample.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Example response', style: AppTextStyles.xs(context, fontWeight: AppTextStyles.bold)),
                  const SizedBox(height: 8),
                  _buildOutputExampleCard(context, service.outputExample),
                ],
                const Divider(height: 32, color: AppColors.border),
                if (_queryControllers.isNotEmpty) ...[
                  Text('Inputs', style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
                  const SizedBox(height: 12),
                  for (final entry in _queryControllers.entries) ...[
                    TextField(
                      controller: entry.value,
                      decoration: InputDecoration(labelText: entry.key),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                Text('Pay with', style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
                const SizedBox(height: 12),
                if (agents.isEmpty) _buildBindAgentCta(context) else _buildAgentPicker(context, agents),
                const SizedBox(height: 18),
                Text('Justification', style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _justificationController,
                  maxLength: _justificationMaxLength,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Why is your agent buying this?'),
                ),
                if (_localValidationError != null || backendError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blockBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.blockBorder),
                    ),
                    child: Text(
                      _localValidationError ?? backendError!,
                      style: AppTextStyles.sm(context, color: AppColors.blockText),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (activeAgents.isEmpty || isSubmitting) ? null : () => _submit(agents),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                          )
                        : const Text('Ask agent to pay'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBindAgentCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No autonomous agent is bound to your account yet.',
            style: AppTextStyles.sm(context, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.router.push(OnboardingRoute(initialStep: 1));
            },
            icon: const Icon(Icons.add_link_rounded, size: 18),
            label: const Text('Bind an agent first'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPicker(BuildContext context, List<AgentModel> agents) {
    return Column(
      children: [
        for (final agent in agents) ...[
          _buildAgentRow(context, agent),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAgentRow(BuildContext context, AgentModel agent) {
    final isActive = agent.status == 'ACTIVE';
    final isSelected = _selectedAgentAddress == agent.agentAddress;

    return Opacity(
      opacity: isActive ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isActive ? () => setState(() => _selectedAgentAddress = agent.agentAddress) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name, style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold)),
                    Text(_shortenAddress(agent.agentAddress), style: AppTextStyles.mono(context, fontSize: 11)),
                  ],
                ),
              ),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.blockBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blockBorder),
                  ),
                  child: Text(agent.status, style: AppTextStyles.xs(context, color: AppColors.blockText)),
                ),
            ],
          ),
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

  Widget _buildDetailRow(BuildContext context, String label, String value, {String? copyValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.sm(context)),
          Flexible(
            child: copyValue != null
                ? InkWell(
                    onTap: () => _copyToClipboard(context, label, copyValue),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(value, style: AppTextStyles.mono(context, fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
                      ],
                    ),
                  )
                : Text(
                    value,
                    style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputExampleCard(BuildContext context, Map<String, dynamic> example) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in example.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: AppTextStyles.xs(context)),
                  Flexible(
                    child: Text(
                      _describeValue(entry.value),
                      style: AppTextStyles.mono(context, fontSize: 11),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _describeValue(dynamic value) {
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label'), behavior: SnackBarBehavior.floating),
    );
  }
}
