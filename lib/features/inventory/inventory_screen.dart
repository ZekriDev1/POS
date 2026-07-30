import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/l10n/translations.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ref.t('inventory'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          const SizedBox(height: 24),
          Text(ref.t('lowStock'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildLowStock(),
          const SizedBox(height: 32),
          Text(ref.t('allProductsStock'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildAllStock(),
        ],
      ),
    );
  }

  Widget _buildLowStock() {
    return FutureBuilder<List<Product>>(
      future: ref.read(databaseProvider).getLowStockProducts(5),
      builder: (ctx, snap) {
        final items = snap.data ?? <Product>[];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(ref.t('stockSufficient'), style: const TextStyle(color: AppTheme.textMuted))),
          );
        }
        return Column(children: [
          for (final p in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(ref.t('stock', {'value': '${p.quantity}'}), style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]);
      },
    );
  }

  Widget _buildAllStock() {
    return FutureBuilder<List<Product>>(
      future: ref.read(databaseProvider).getAllProducts(),
      builder: (ctx, snap) {
        final products = snap.data ?? <Product>[];
        if (products.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(ref.t('noProducts'), style: const TextStyle(color: AppTheme.textMuted))),
          );
        }
        return Column(children: [
          for (final p in products)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.quantity <= 5 ? AppTheme.danger.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${p.quantity}', style: TextStyle(
                    color: p.quantity <= 5 ? AppTheme.danger : Colors.green,
                    fontWeight: FontWeight.w600,
                  )),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}
