import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/license/activation_service.dart';

final activationServiceProvider = Provider((_) => ActivationService());

final activationStateProvider = StateNotifierProvider<ActivationNotifier, AsyncValue<bool>>((ref) {
  return ActivationNotifier(ref.read(activationServiceProvider));
});

class ActivationNotifier extends StateNotifier<AsyncValue<bool>> {
  final ActivationService _service;
  ActivationNotifier(this._service) : super(const AsyncLoading()) {
    _check();
  }

  Future<void> _check() async {
    final activated = await _service.isActivated();
    state = AsyncData(activated);
  }

  Future<ActivationResult> activate(String key) async {
    state = const AsyncLoading();
    final result = await _service.activate(key);
    state = AsyncData(result.success);
    return result;
  }
}

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _keyController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter an activation key');
      return;
    }
    final result = await ref.read(activationStateProvider.notifier).activate(key);
    if (!mounted) return;
    if (result.success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.cardBg,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Activation Successful', style: TextStyle(color: AppTheme.textMain)),
            ],
          ),
          content: const Text(
            'Thanks for purchasing the product.\n\nPlease close the app and re-open it to start using RestroPOS.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => exit(0),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Close & Reopen'),
            ),
          ],
        ),
      );
      return;
    }
    if (result.code == 'ALREADY_USED') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.cardBg,
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('License Already In Use', style: TextStyle(color: AppTheme.textMain)),
            ],
          ),
          content: const Text(
            'This license is already activated on another device.\n\n'
            'To transfer the license to this device, please contact support:\n'
            '+212 6 91 15 73 63',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppTheme.cardBg,
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.danger, size: 28),
            SizedBox(width: 10),
            Text('Activation Failed', style: TextStyle(color: AppTheme.textMain)),
          ],
        ),
        content: const Text(
          'You need to buy a license.\nPlease contact the support team:\n+212 6 91 15 73 63',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [AppTheme.cardShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.point_of_sale, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              const Text('RestroPOS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              const SizedBox(height: 8),
              const Text('Activate your license to continue', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
              const SizedBox(height: 32),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  hintText: 'Enter activation key',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _activate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Activate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
