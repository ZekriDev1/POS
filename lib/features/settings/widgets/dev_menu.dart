import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/license/activation_service.dart';
import 'package:restropos/features/activation/screens/activation_screen.dart';

class DevMenu extends ConsumerStatefulWidget {
  const DevMenu({super.key});

  @override
  ConsumerState<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends ConsumerState<DevMenu> {
  String _output = '';
  bool _loading = false;

  Future<void> _generateLicense() async {
    setState(() { _loading = true; _output = ''; });
    try {
      final res = await http.post(
        Uri.parse('https://pyyprebhtuwmyxkpzosj.supabase.co/functions/v1/generate-license'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'count': 1, 'expires_in_days': 365}),
      );
      if (res.statusCode == 404) {
        _output = 'Function not deployed.\n\n'
            'Run this in your terminal:\n'
            '  supabase functions deploy generate-license --no-verify-jwt\n\n'
            'Or use SQL in Supabase Editor:\n'
            '  INSERT INTO licenses (license_key, is_active)\n'
            '  VALUES (upper(\'RESTROPOS-\'\n'
            '    || substr(md5(random()::text),1,4)||\'-\'\n'
            '    || substr(md5(random()::text),1,4)||\'-\'\n'
            '    || substr(md5(random()::text),1,4)), true)\n'
            '  RETURNING license_key;';
      } else {
        _output = res.body;
      }
    } catch (e) {
      _output = 'Error: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkLicense(String key) async {
    setState(() { _loading = true; _output = ''; });
    try {
      final res = await http.post(
        Uri.parse('https://pyyprebhtuwmyxkpzosj.supabase.co/functions/v1/check-license'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': key}),
      );
      _output = res.body;
    } catch (e) {
      _output = 'Error: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _dbStats() async {
    setState(() { _loading = true; _output = ''; });
    try {
      final db = ref.read(databaseProvider);
      final products = await db.getProductCount();
      final categories = await db.getCategoryCount();
      final sales = await db.getTodaySaleCount();
      final revenue = await db.getTotalRevenue();
      _output = 'Products: $products\nCategories: $categories\nToday Sales: $sales\nTotal Revenue: \$${revenue.toStringAsFixed(2)}';
    } catch (e) {
      _output = 'Error: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  final _keyCtrl = TextEditingController();

  Future<void> _signOut() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('This will deactivate the license on this device. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _loading = true; _output = 'Signing out...'; });
    try {
      await ActivationService().deactivate();
      _output = 'Signed out successfully.';
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _output = 'Error: $e';
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.cardBg,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.textMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.developer_mode, color: AppTheme.textMain, size: 28),
                ),
                const SizedBox(width: 14),
                const Text('Developer Menu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generateLicense,
                  icon: const Icon(Icons.vpn_key, size: 18),
                  label: const Text('Generate License'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _dbStats,
                  icon: const Icon(Icons.storage, size: 18),
                  label: const Text('DB Stats'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyCtrl,
                    decoration: InputDecoration(
                      hintText: 'License key to check...',
                      filled: true, fillColor: AppTheme.bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading || _keyCtrl.text.trim().isEmpty
                      ? null
                      : () => _checkLicense(_keyCtrl.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Check'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : SingleChildScrollView(
                        child: SelectableText(
                          _output.isEmpty ? 'Output will appear here...' : _output,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: _output.isEmpty ? Colors.grey : const Color(0xFF4EC9B0),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
