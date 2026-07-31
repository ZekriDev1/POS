import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restropos/app_shell.dart';
import 'package:restropos/core/l10n/language_picker_screen.dart';
import 'package:restropos/core/l10n/translations.dart';
import 'package:restropos/core/license/activation_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/features/activation/screens/activation_screen.dart';
import 'package:restropos/core/services/update/update_providers.dart';
import 'package:restropos/core/utils/currency_formatter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pyyprebhtuwmyxkpzosj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5eXByZWJodHV3bXl4a3B6b3NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzNTcxMDEsImV4cCI6MjEwMDkzMzEwMX0.ddr52weOXuGi0wVsnzhzYrHjzEHi6xt2V49l_PcgxVo',
  );

  runApp(const ProviderScope(child: CashManagerApp()));
}

class CashManagerApp extends ConsumerWidget {
  const CashManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isRtl = locale.languageCode == 'ar';
    return MaterialApp(
      title: ref.t('appTitle'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
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
  bool _localeReady = false;
  bool _isFirstLaunch = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ref.read(localeProvider.notifier).load();
    final prefs = await SharedPreferences.getInstance();
    CurrencyFormatter.symbol = prefs.getString('currency_symbol') ?? 'DH';
    final hasLocale = prefs.containsKey('locale');
    if (mounted) {
      setState(() {
        _isFirstLaunch = !hasLocale;
        _localeReady = true;
      });
    }
    if (hasLocale) {
      await _checkActivation();
    }
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

  void _onLanguagePicked() {
    setState(() => _isFirstLaunch = false);
    _checkActivation();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    if (!_localeReady) {
      return Scaffold(
        key: ValueKey(locale),
        backgroundColor: AppTheme.bgColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_isFirstLaunch) {
      return LanguagePickerScreen(onComplete: _onLanguagePicked);
    }

    if (_checking) {
      return Scaffold(
        key: ValueKey(locale),
        backgroundColor: AppTheme.bgColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (!_activated) return ActivationScreen(key: ValueKey(locale));
    ref.listen(updateCheckProvider, (prev, next) {});
    return AppShell(key: ValueKey(locale));
  }
}
