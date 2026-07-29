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

  Future<String?> activate(String key) async {
    state = const AsyncLoading();
    final result = await _service.activate(key);
    if (result.success) {
      state = const AsyncData(true);
      return null;
    }
    state = const AsyncData(false);
    return result.message;
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
    final error = await ref.read(activationStateProvider.notifier).activate(key);
    setState(() => _error = error);
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
