import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restropos/features/settings/widgets/update_settings_section.dart';
import 'package:restropos/core/l10n/translations.dart';
import 'package:restropos/core/utils/currency_formatter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'DH');
  final _cashierCtrl = TextEditingController();
  String? _logoPath;
  final _picker = ImagePicker();
  bool _loaded = false;
  bool _backingUp = false;
  bool _restoring = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _cashierCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _nameCtrl.text = prefs.getString('store_name') ?? '';
    _cashierCtrl.text = prefs.getString('cashier_name') ?? '';
    _logoPath = prefs.getString('store_logo');
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _nameCtrl.text);
    await prefs.setString('cashier_name', _cashierCtrl.text);
    await prefs.setString('currency_symbol', _currencyCtrl.text);
    CurrencyFormatter.symbol = _currencyCtrl.text;
    if (_logoPath != null) await prefs.setString('store_logo', _logoPath!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.t('settingsSaved'))));
    }
  }

  Future<void> _backup() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: ref.t('saveBackup'),
      fileName: 'restropos-backup-${DateTime.now().millisecondsSinceEpoch}.db',
    );
    if (path == null) return;
    setState(() => _backingUp = true);
    try {
      await ref.read(databaseProvider).backupDatabase(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.t('backupSuccess', {'path': path}))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.t('backupFailed', {'error': '$e'})), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: ref.t('selectBackup'),
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('restoreData')),
        content: Text(ref.t('restoreConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ref.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(ref.t('restore'))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _restoring = true);
    try {
      await ref.read(databaseProvider).restoreDatabase(result.files.single.path!);
      ref.invalidate(databaseProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.t('restoreSuccess'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.t('restoreFailed', {'error': '$e'})), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (ctx, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(ref.t('storeName'), _nameCtrl),
                  const SizedBox(height: 20),
                  _buildField(ref.t('currencySymbol'), _currencyCtrl),
                  const SizedBox(height: 20),
                  _buildField(ref.t('cashierName'), _cashierCtrl),
                  const SizedBox(height: 20),
                  Text(ref.t('storeLogo'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery);
                      if (file != null) setState(() => _logoPath = file.path);
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor, width: 2, strokeAlign: BorderSide.strokeAlignInside),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.bgColor,
                      ),
                      child: _logoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(_logoPath!), fit: BoxFit.cover, width: double.infinity, height: 80),
                            )
                          : const Center(child: Icon(Icons.add_photo_alternate, color: AppTheme.textMuted, size: 28)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(ref.t('saveSettings'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildLanguageCard(),
            const SizedBox(height: 24),
            _buildBackupCard(),
            const SizedBox(height: 24),
            const UpdateSettingsSection(),
            const SizedBox(height: 24),
            _buildCopyrightCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard() {
    final locale = ref.watch(localeProvider);
    final code = locale.languageCode;
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.language, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(ref.t('selectLanguage'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: code,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              DropdownMenuItem(value: 'en', child: Text('🇬🇧  ${ref.t('english')}')),
              DropdownMenuItem(value: 'fr', child: Text('🇫🇷  ${ref.t('french')}')),
              DropdownMenuItem(value: 'ar', child: Text('🇲🇦  ${ref.t('arabic')}')),
            ],
            onChanged: (v) {
              if (v != null && v != code) {
                ref.read(localeProvider.notifier).setLocale(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.backup, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(ref.t('backupRestore'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          ]),
          const SizedBox(height: 16),
          Text(ref.t('backupDesc'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _backingUp ? null : _backup,
                icon: _backingUp
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_download, size: 18),
                label: Text(_backingUp ? ref.t('backingUp') : ref.t('backup'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _restoring ? null : _restore,
                icon: _restoring
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_upload, size: 18),
                label: Text(_restoring ? ref.t('restoring') : ref.t('restore'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textMain, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCopyrightCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.copyright, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Akram Zekri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const SizedBox(height: 2),
              Text('+212 691157363', style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            filled: true, fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
