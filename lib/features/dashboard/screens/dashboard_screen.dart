import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';
import 'package:restropos/features/dashboard/widgets/stat_card.dart';

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
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 16, runSpacing: 16,
                    children: [
                      SizedBox(width: 220, child: StatCard(title: 'Total Products', value: '${s['products']}', icon: Icons.inventory_2)),
                      SizedBox(width: 220, child: StatCard(title: 'Categories', value: '${s['categories']}', icon: Icons.category)),
                      SizedBox(width: 220, child: StatCard(title: "Today's Sales", value: CurrencyFormatter.format(s['todaySales'] as double), icon: Icons.payments)),
                      SizedBox(width: 220, child: StatCard(title: 'Total Orders', value: '${s['totalOrders']}', icon: Icons.receipt_long)),
                      SizedBox(width: 220, child: StatCard(title: 'Items Sold', value: '${s['itemsSold']}', icon: Icons.shopping_cart_checkout)),
                      SizedBox(width: 220, child: StatCard(title: 'Total Revenue', value: CurrencyFormatter.format(s['totalRevenue'] as double), icon: Icons.account_balance_wallet)),
                      SizedBox(width: 220, child: StatCard(title: 'Monthly Revenue', value: CurrencyFormatter.format(s['monthlyRevenue'] as double), icon: Icons.trending_up)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Low Stock Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _LowStockList(db: db),
                  const SizedBox(height: 32),
                  const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
    final products = await db.getProductCount();
    final categories = await db.getCategoryCount();
    final todaySales = await db.getTodayRevenue();
    final totalOrders = await db.getTodaySaleCount();
    final itemsSold = await db.getTotalItemsSold();
    final totalRevenue = await db.getTotalRevenue();
    final monthlyRevenue = await db.getMonthlyRevenue();
    return {
      'products': products,
      'categories': categories,
      'todaySales': todaySales,
      'totalOrders': totalOrders,
      'itemsSold': itemsSold,
      'totalRevenue': totalRevenue,
      'monthlyRevenue': monthlyRevenue,
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
        final items = snap.data ?? <Product>[];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('All products have sufficient stock', style: TextStyle(color: AppTheme.textMuted))),
          );
        }
        return Column(children: items.map((p) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(p.name), Text('Stock: ${p.quantity}', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600))],
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
        final sales = snap.data ?? <Sale>[];
        if (sales.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('No orders yet', style: TextStyle(color: AppTheme.textMuted))),
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
