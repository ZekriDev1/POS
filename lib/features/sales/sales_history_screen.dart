import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          ]),
          const SizedBox(height: 24),
          FutureBuilder(
            future: ref.read(databaseProvider).getAllSales(),
            builder: (ctx, snap) {
              final sales = snap.data ?? [];
              if (sales.isEmpty) {
                return Center(child: Container(
                  padding: const EdgeInsets.all(60),
                  child: const Text('No orders yet', style: TextStyle(color: AppTheme.textMuted)),
                ));
              }
              return Column(children: sales.reversed.map((s) => Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('#${s.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      Text(CurrencyFormatter.format(s.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year} ${s.createdAt.hour.toString().padLeft(2,'0')}:${s.createdAt.minute.toString().padLeft(2,'0')}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future: ref.read(databaseProvider).getSaleItems(s.id),
                      builder: (ctx, itemSnap) {
                        final items = itemSnap.data ?? [];
                        return Text(items.map((i) => '${i.productId} x${i.quantity}').join(', '),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis);
                      },
                    ),
                  ],
                ),
              )).toList());
            },
          ),
        ],
      ),
    );
  }
}
