import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/l10n/translations.dart';
import 'package:restropos/core/utils/app_theme.dart';

class LanguagePickerScreen extends ConsumerWidget {
  final VoidCallback onComplete;

  const LanguagePickerScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locales = [
      _Lang('English', 'en', '🇬🇧'),
      _Lang('Français', 'fr', '🇫🇷'),
      _Lang('العربية', 'ar', '🇲🇦'),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [AppTheme.cardShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  Translations.get('appTitle', 'en'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              Text(
                Translations.get('selectLanguage', 'en'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain),
              ),
              const SizedBox(height: 4),
              Text(
                Translations.get('languageSubtitle', 'en'),
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              ...locales.map((lang) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref.read(localeProvider.notifier).setLocale(lang.code);
                          onComplete();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Text(lang.flag, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Text(lang.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                            const Spacer(),
                            Text(Translations.get(lang.code == 'en' ? 'english' : lang.code == 'fr' ? 'french' : 'arabic', lang.code),
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lang {
  final String name;
  final String code;
  final String flag;
  const _Lang(this.name, this.code, this.flag);
}
