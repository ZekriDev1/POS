import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadWallet(db),
        builder: (ctx, snap) {
          final w = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wallet', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const SizedBox(height: 24),
              if (w != null) ...[
                Wrap(spacing: 16, runSpacing: 16, children: [
                  _statBox("Today's Sales", CurrencyFormatter.format(w['todaySales'] as double), Icons.payments),
                  _statBox('Total Orders', '${w['totalOrders']}', Icons.receipt_long),
                  _statBox('Items Sold', '${w['itemsSold']}', Icons.shopping_cart_checkout),
                ]),
                const SizedBox(height: 32),
                const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _transactionsList(db),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadWallet(AppDatabase db) async {
    final todaySales = await db.getTodayRevenue();
    final totalOrders = await db.getTodaySaleCount();
    final itemsSold = await db.getTotalItemsSold();
    return {'todaySales': todaySales, 'totalOrders': totalOrders, 'itemsSold': itemsSold};
  }

  Widget _statBox(String title, String value, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppTheme.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _transactionsList(AppDatabase db) {
    return FutureBuilder<List<Sale>>(
      future: db.getAllSales(),
      builder: (ctx, snap) {
        final sales = snap.data ?? <Sale>[];
        if (sales.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('No transactions yet', style: TextStyle(color: AppTheme.textMuted))),
          );
        }
        return Column(children: sales.reversed.take(10).map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${s.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
            Text(CurrencyFormatter.format(s.total), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        )).toList());
      },
    );
  }
}
