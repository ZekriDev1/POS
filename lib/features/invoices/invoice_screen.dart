import 'package:flutter/material.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _tvaCtrl = TextEditingController();
  final _tvaRateCtrl = TextEditingController(text: '20');
  final _footerCtrl = TextEditingController();
  bool _showTax = true;
  bool _loaded = false;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _tvaCtrl.dispose();
    _tvaRateCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _companyCtrl.text = prefs.getString('invoice_company') ?? '';
    _phoneCtrl.text = prefs.getString('invoice_phone') ?? '';
    _addressCtrl.text = prefs.getString('invoice_address') ?? '';
    _tvaCtrl.text = prefs.getString('invoice_tva') ?? '';
    _tvaRateCtrl.text = prefs.getString('invoice_tva_rate') ?? '20';
    _footerCtrl.text = prefs.getString('invoice_footer') ?? '';
    _showTax = prefs.getBool('invoice_show_tax') ?? true;
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invoice_company', _companyCtrl.text);
    await prefs.setString('invoice_phone', _phoneCtrl.text);
    await prefs.setString('invoice_address', _addressCtrl.text);
    await prefs.setString('invoice_tva', _tvaCtrl.text);
    await prefs.setString('invoice_tva_rate', _tvaRateCtrl.text);
    await prefs.setString('invoice_footer', _footerCtrl.text);
    await prefs.setBool('invoice_show_tax', _showTax);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice settings saved')));
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
            const Text('Invoice Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            const SizedBox(height: 24),
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Company / Store Name', _companyCtrl),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field('Phone', _phoneCtrl)),
                    const SizedBox(width: 16),
                    Expanded(child: _field('TVA Number', _tvaCtrl)),
                  ]),
                  const SizedBox(height: 16),
                  _field('Address', _addressCtrl),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _field('TVA Rate (%)', _tvaRateCtrl)),
                    const SizedBox(width: 16),
                    Expanded(child: _field('Footer', _footerCtrl)),
                  ]),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Show TVA on invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    Switch(
                      value: _showTax,
                      onChanged: (v) => setState(() => _showTax = v),
                      activeColor: AppTheme.primary,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Invoice Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
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
