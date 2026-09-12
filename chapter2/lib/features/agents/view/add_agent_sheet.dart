import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';

class AddAgentSheet extends StatefulWidget {
  const AddAgentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddAgentSheet(),
    );
  }

  @override
  State<AddAgentSheet> createState() => _AddAgentSheetState();
}

class _AddAgentSheetState extends State<AddAgentSheet> {
  final _nameController = TextEditingController(text: 'Cloud Ops Agent #2');
  String _selectedRole = 'API & Cloud Services';
  double _initialLimit = 300.0;
  bool _isCreating = false;

  final List<String> _roles = [
    'API & Cloud Services',
    'DeFi Treasury Rebalance',
    'Vendor Payroll & Invoicing',
    'x402 Micro-Transactions',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() => _isCreating = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _isCreating = false);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Agent "${_nameController.text.trim()}" registered & bounded by Chapter2Guard',
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
                    Icons.smart_toy_rounded,
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
                        'Spawn Supervised Agent',
                        style: AppTextStyles.xl(context),
                      ),
                      Text(
                        'Register a new autonomous worker under Gnosis Safe',
                        style: AppTextStyles.sm(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Agent Name Input
            Text(
              'Agent Identifier / Name',
              style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: AppTextStyles.md(context, color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.cardSurface,
                hintText: 'e.g. Google Cloud Vertex AI Bot',
                hintStyle: AppTextStyles.sm(context, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Role Dropdown
            Text(
              'Operational Scope',
              style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  items: _roles.map((r) {
                    return DropdownMenuItem<String>(
                      value: r,
                      child: Text(
                        r,
                        style: AppTextStyles.sm(context, color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Starting Limit Slider
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
                        'Autonomous Daily Cap',
                        style: AppTextStyles.md(context, fontWeight: AppTextStyles.semiBold),
                      ),
                      Text(
                        '\$${_initialLimit.toStringAsFixed(0)} USDC',
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
                    'Agent can execute up to this amount without human interruption',
                    style: AppTextStyles.xs(context),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.brandPrimary,
                      inactiveTrackColor: AppColors.cardBorder,
                      thumbColor: AppColors.brandPrimary,
                    ),
                    child: Slider(
                      value: _initialLimit,
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      onChanged: (val) => setState(() => _initialLimit = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isCreating ? null : _handleCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPillBackground,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Spawn & Enforce Safe Guard',
                      style: AppTextStyles.md(
                        context,
                        color: Colors.white,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
