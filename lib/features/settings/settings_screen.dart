import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restropos/features/settings/widgets/update_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'DH');
  final _cashierCtrl = TextEditingController();
  String? _logoPath;
  final _picker = ImagePicker();
  bool _loaded = false;

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
    if (_logoPath != null) await prefs.setString('store_logo', _logoPath!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (ctx, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            const SizedBox(height: 24),
            Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('Store Name', _nameCtrl),
                  const SizedBox(height: 20),
                  _buildField('Currency Symbol', _currencyCtrl),
                  const SizedBox(height: 20),
                  _buildField('Cashier Name', _cashierCtrl),
                  const SizedBox(height: 20),
                  const Text('Store Logo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
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
                      child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const UpdateSettingsSection(),
          ],
        ),
      ),
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
