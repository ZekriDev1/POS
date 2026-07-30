import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/services/printer_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';
import 'package:restropos/features/invoices/widgets/receipt_widget.dart';
import 'package:restropos/features/pos/pos_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:restropos/core/l10n/translations.dart';

class BillingPanel extends ConsumerWidget {
  const BillingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: rtl
            ? const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24))
            : const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('bills'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(
            child: cart.items.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text(context.t('cartEmpty'), style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ))
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      return Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _qtyBtn(() => notifier.updateQty(i, -1), Icons.remove),
                                    const SizedBox(width: 8),
                                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    _qtyBtn(() => notifier.updateQty(i, 1), Icons.add),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(CurrencyFormatter.format(item.price * item.quantity),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      );
                    },
                  ),
          ),
          if (cart.items.isNotEmpty) ...[
            const Divider(),
            _summaryRow(context.t('subtotal'), CurrencyFormatter.format(cart.subtotal)),
            const SizedBox(height: 12),
            Text(context.t('paymentMethod'), style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Row(children: [
              _paymentChip(context.t('cash'), cart.paymentMethod == 'cash', () => notifier.setPaymentMethod('cash')),
              const SizedBox(width: 8),
              _paymentChip(context.t('card'), cart.paymentMethod == 'card', () => notifier.setPaymentMethod('card')),
            ]),
            const Divider(),
            _summaryRow(context.t('total'), CurrencyFormatter.format(cart.total), bold: true, large: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _checkout(context, ref, cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(context.t('printBill'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qtyBtn(VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textMuted),
      ),
    );
  }

  Widget _paymentChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.borderColor),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : AppTheme.textMain,
          fontWeight: FontWeight.w500, fontSize: 13,
        )),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: large ? 14 : 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        )),
        Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          fontSize: large ? 20 : 14,
          color: AppTheme.textMain,
        )),
      ]),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref, CartState cart) async {
    if (cart.items.isEmpty) return;

    final db = ref.read(databaseProvider);
    final notifier = ref.read(cartProvider.notifier);
    final now = DateTime.now();
    final saleId = const Uuid().v4();
    final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';
    final subtotal = cart.subtotal;

    final prefs = await SharedPreferences.getInstance();
    final storeName = prefs.getString('invoice_company') ?? prefs.getString('store_name') ?? ref.t('appTitle');
    final phone = prefs.getString('invoice_phone');
    final address = prefs.getString('invoice_address');
    final tvaNumber = prefs.getString('invoice_tva');
    final taxRateStr = prefs.getString('invoice_tva_rate') ?? '20';
    final taxRate = double.tryParse(taxRateStr) ?? 20;
    final showTax = prefs.getBool('invoice_show_tax') ?? true;
    final footer = prefs.getString('invoice_footer');
    final cashier = prefs.getString('cashier_name') ?? '';

    final double effectiveTax = showTax ? subtotal * taxRate / 100 : 0;
    final double total = subtotal + effectiveTax;

    await db.createSale(
      id: saleId,
      invoiceNumber: invoiceNumber,
      subtotal: subtotal,
      tax: effectiveTax,
      total: total,
      paymentMethod: cart.paymentMethod,
      createdAt: now,
    );

    for (final item in cart.items) {
      await db.createSaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        productId: item.id,
        quantity: item.quantity,
        price: item.price,
      );
      final product = await db.getProductById(item.id);
      if (product != null) {
        await db.updateProductStock(item.id, product.quantity - item.quantity);
      }
    }

    final nowFormatted = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeFormatted = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final paymentLabel = cart.paymentMethod == 'cash' ? context.t('cashLabel') : context.t('cardLabel');

    final items = cart.items
        .map((i) => ReceiptItem(name: i.name, unit: context.t('unitLabel'), quantity: i.quantity, price: i.price))
        .toList();

    final printLocale = Localizations.localeOf(context).languageCode;
    final printCurrency = prefs.getString('currency_symbol') ?? 'DH';

    if (context.mounted) {
      await showDialog(
        context: context,
        useSafeArea: false,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: _ReceiptPreviewDialog(
            receipt: ReceiptWidget(
              storeName: storeName,
              storePhone: phone?.isNotEmpty == true ? phone : null,
              storeCity: address?.isNotEmpty == true ? address : null,
              storeTvaNumber: tvaNumber?.isNotEmpty == true ? tvaNumber : null,
              date: nowFormatted,
              time: timeFormatted,
              orderNumber: invoiceNumber,
              cashier: cashier,
              paymentMethod: paymentLabel,
              items: items,
              taxRate: showTax ? taxRate : 0,
              footerMessage: footer?.isNotEmpty == true ? footer : null,
              currencySymbol: printCurrency,
            ),
            onPrint: () {
              Navigator.of(ctx).pop();
              final printer = PrinterService();
              printer.printInvoice(
                companyName: storeName,
                phone: phone,
                address: address,
                tvaNumber: tvaNumber,
                invoiceNumber: invoiceNumber,
                date: now,
                customerName: null,
                items: cart.items
                    .map((i) => InvoiceItem(name: i.name, quantity: i.quantity, price: i.price))
                    .toList(),
                subtotal: subtotal,
                tax: effectiveTax,
                total: total,
                paymentMethod: cart.paymentMethod,
                footer: footer,
                showTax: showTax,
                taxRate: taxRate,
                locale: printLocale,
                currencySymbol: printCurrency,
              );
            },
          ),
        ),
      );
    }

    notifier.clear();
  }

}

class _ReceiptPreviewDialog extends StatelessWidget {
  final ReceiptWidget receipt;
  final VoidCallback onPrint;

  const _ReceiptPreviewDialog({
    required this.receipt,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.t('receiptPreview'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined),
                  tooltip: context.t('print'),
                  onPressed: onPrint,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: receipt,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.t('close')),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(context.t('print')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
