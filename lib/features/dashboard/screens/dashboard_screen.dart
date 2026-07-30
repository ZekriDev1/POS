import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';
import 'package:restropos/features/dashboard/widgets/stat_card.dart';
import 'package:restropos/core/l10n/translations.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _loadStats(db),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(child: Text('${snap.error}', style: const TextStyle(color: Colors.red)));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 16, runSpacing: 16,
                    children: [
                      SizedBox(width: 220, child: StatCard(title: context.t('totalProducts'), value: '${s['products']}', icon: Icons.inventory_2)),
                      SizedBox(width: 220, child: StatCard(title: context.t('totalCategories'), value: '${s['categories']}', icon: Icons.category)),
                      SizedBox(width: 220, child: StatCard(title: context.t('todaySales'), value: CurrencyFormatter.format((s['todaySales'] as num).toDouble()), icon: Icons.payments)),
                      SizedBox(width: 220, child: StatCard(title: context.t('totalOrders'), value: '${s['totalOrders']}', icon: Icons.receipt_long)),
                      SizedBox(width: 220, child: StatCard(title: context.t('itemsSold'), value: '${s['itemsSold']}', icon: Icons.shopping_cart_checkout)),
                      SizedBox(width: 220, child: StatCard(title: context.t('totalRevenue'), value: CurrencyFormatter.format((s['totalRevenue'] as num).toDouble()), icon: Icons.account_balance_wallet)),
                      SizedBox(width: 220, child: StatCard(title: context.t('monthlyRevenue'), value: CurrencyFormatter.format((s['monthlyRevenue'] as num).toDouble()), icon: Icons.trending_up)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(context.t('lowStock'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _LowStockList(db: db),
                  const SizedBox(height: 32),
                  Text(context.t('recentOrders'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _RecentOrders(db: db),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadStats(AppDatabase db) async {
    int p, c, o, i;
    double ts, tr, mr;
    try { p = await db.getProductCount(); } catch (_) { p = 0; }
    try { c = await db.getCategoryCount(); } catch (_) { c = 0; }
    try { ts = await db.getTodayRevenue(); } catch (_) { ts = 0.0; }
    try { o = await db.getTodaySaleCount(); } catch (_) { o = 0; }
    try { i = await db.getTotalItemsSold(); } catch (_) { i = 0; }
    try { tr = await db.getTotalRevenue(); } catch (_) { tr = 0.0; }
    try { mr = await db.getMonthlyRevenue(); } catch (_) { mr = 0.0; }
    return {
      'products': p,
      'categories': c,
      'todaySales': ts,
      'totalOrders': o,
      'itemsSold': i,
      'totalRevenue': tr,
      'monthlyRevenue': mr,
    };
  }
}

class _LowStockList extends StatelessWidget {
  final AppDatabase db;
  const _LowStockList({required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: db.getLowStockProducts(5),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('${snap.error}', style: const TextStyle(color: Colors.red))),
          );
        }
        final items = snap.data ?? <Product>[];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(context.t('stockSufficient'), style: const TextStyle(color: AppTheme.textMuted))),
          );
        }
        return Column(children: items.map((p) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(p.name), Text(context.t('stock', {'value': '${p.quantity}'}), style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600))],
          ),
        )).toList());
      },
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final AppDatabase db;
  const _RecentOrders({required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Sale>>(
      future: db.getAllSales(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('${snap.error}', style: const TextStyle(color: Colors.red))),
          );
        }
        final sales = snap.data ?? <Sale>[];
        if (sales.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(context.t('noOrders'), style: const TextStyle(color: AppTheme.textMuted))),
          );
        }
        final recent = sales.reversed.take(5).toList();
        return Column(children: recent.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('#${s.invoiceNumber} — ${_formatDate(s.createdAt)}', overflow: TextOverflow.ellipsis)),
              Text(CurrencyFormatter.format(s.total), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        )).toList());
      },
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
