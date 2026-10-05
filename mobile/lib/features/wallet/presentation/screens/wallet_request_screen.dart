import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

class WalletRequestScreen extends ConsumerStatefulWidget {
  const WalletRequestScreen({required this.isDeposit, super.key});
  final bool isDeposit;

  @override
  ConsumerState<WalletRequestScreen> createState() =>
      _WalletRequestScreenState();
}

class _WalletRequestScreenState extends ConsumerState<WalletRequestScreen> {
  final _amountController = TextEditingController(text: '500');
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final account = ref.read(exV2AccountProvider).value;
      if (account == null) throw const ExV2TokenMissing();
      await ref
          .read(exV2AccountProvider.notifier)
          .createWalletRequest(
            isDeposit: widget.isDeposit,
            amount: amount,
            note: _noteController.text.trim(),
          );
      if (!mounted) return;
      context.pop();
    } on ExV2RequestFailure catch (error) {
      if (!mounted) return;
      final destination = walletRequestFailureDestination(
        isDeposit: widget.isDeposit,
        error: error,
      );
      if (destination != null) {
        context.go(destination);
        return;
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.isDeposit ? 'Nạp' : 'Rút';
    return Scaffold(
      appBar: AppBar(title: Text('$action tiền demo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tiền USD',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Ghi chú yêu cầu'),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Gửi yêu cầu $action'),
          ),
        ],
      ),
    );
  }
}

String? walletRequestFailureDestination({
  required bool isDeposit,
  required Object error,
}) =>
    isDeposit &&
        error is ExV2RequestFailure &&
        error.statusCode == 409 &&
        error.code == 'DEPOSIT_CANONICAL_CONTEXT_REQUIRED'
    ? '/accounts/add'
    : null;
