import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restropos/app_shell.dart';
import 'package:restropos/core/license/activation_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/features/activation/screens/activation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const ProviderScope(child: RestroPOSApp()));
}

class RestroPOSApp extends StatelessWidget {
  const RestroPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RestroPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppEntry(),
    );
  }
}

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  final _activationService = ActivationService();
  bool _checking = true;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    final activated = await _activationService.isActivated();
    if (mounted) {
      setState(() {
        _activated = activated;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    return _activated ? const AppShell() : const ActivationScreen();
  }
}
