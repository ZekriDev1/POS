import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restropos/app_shell.dart';
import 'package:restropos/core/license/activation_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/features/activation/screens/activation_screen.dart';
import 'package:restropos/core/services/update/update_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pyyprebhtuwmyxkpzosj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5eXByZWJodHV3bXl4a3B6b3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzNTcxMDEsImV4cCI6MjEwMDkzMzEwMX0.ddr52weOXuGi0wVsnzhzYrHjzEHi6xt2V49l_PcgxVo',
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
    if (!_activated) return const ActivationScreen();
    ref.listen(updateCheckProvider, (prev, next) {});
    return const AppShell();
  }
}
