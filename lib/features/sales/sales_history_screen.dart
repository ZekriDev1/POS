import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';
import 'package:restropos/core/l10n/translations.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder(
            future: ref.read(databaseProvider).getAllSales(),
            builder: (ctx, snap) {
              final sales = snap.data ?? [];
              if (sales.isEmpty) {
                return Center(child: Container(
                  padding: const EdgeInsets.all(60),
                  child: Text(context.t('noOrders'), style: const TextStyle(color: AppTheme.textMuted)),
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
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(CurrencyFormatter.format(s.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(context.t('deleteSale')),
                                content: Text(context.t('deleteSaleConfirm', {'number': s.invoiceNumber})),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('cancel'))),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: Text(context.t('delete')),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await ref.read(databaseProvider).deleteSale(s.id);
                              setState(() {});
                            }
                          },
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete, size: 16, color: Colors.red),
                          ),
                        ),
                      ]),
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
