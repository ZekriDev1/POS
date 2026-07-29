import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/services/printer_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';
import 'package:restropos/features/pos/pos_screen.dart';
import 'package:uuid/uuid.dart';

class BillingPanel extends ConsumerWidget {
  const BillingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      width: 380,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bills', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_shopping_cart, size: 48, color: AppTheme.textMuted),
                      SizedBox(height: 12),
                      Text('Cart is empty', style: TextStyle(color: AppTheme.textMuted)),
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
            _summaryRow('Subtotal', CurrencyFormatter.format(cart.subtotal)),
            const SizedBox(height: 12),
            const Text('Payment Method', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Row(children: [
              _paymentChip('Cash', cart.paymentMethod == 'cash', () => notifier.setPaymentMethod('cash')),
              const SizedBox(width: 8),
              _paymentChip('Card', cart.paymentMethod == 'card', () => notifier.setPaymentMethod('card')),
            ]),
            const Divider(),
            _summaryRow('Total', CurrencyFormatter.format(cart.total), bold: true, large: true),
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
                child: const Text('PRINT BILL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

    await db.createSale(
      id: saleId,
      invoiceNumber: invoiceNumber,
      subtotal: subtotal,
      total: subtotal,
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

    final printer = PrinterService();
    await printer.printInvoice(
      companyName: 'RestroPOS',
      phone: null,
      address: null,
      tvaNumber: null,
      invoiceNumber: invoiceNumber,
      date: now,
      customerName: null,
      items: cart.items.map((i) => InvoiceItem(name: i.name, quantity: i.quantity, price: i.price)).toList(),
      subtotal: subtotal,
      tax: 0,
      total: subtotal,
      paymentMethod: cart.paymentMethod,
      footer: null,
      showTax: false,
      taxRate: 0,
    );

    notifier.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale completed')));
    }
  }
}
