import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Categories', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ElevatedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          FutureBuilder(
            future: ref.read(databaseProvider).getAllCategories(),
            builder: (ctx, snap) {
              final cats = snap.data ?? <dynamic>[];
              if (cats.isEmpty) {
                return Center(child: Container(
                  padding: const EdgeInsets.all(40),
                  child: const Text('No categories yet', style: TextStyle(color: AppTheme.textMuted)),
                ));
              }
              return Wrap(spacing: 12, runSpacing: 12, children: cats.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _deleteCategory(c.id),
                    child: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                  ),
                ]),
              )).toList());
            },
          ),
        ],
      ),
    );
  }

  void _addCategory() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Category'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Category name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          await ref.read(databaseProvider).createCategory(
            'cat${DateTime.now().millisecondsSinceEpoch}', ctrl.text.trim());
          if (ctx.mounted) Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('Add')),
      ],
    ));
  }

  void _deleteCategory(String id) async {
    await ref.read(databaseProvider).deleteCategory(id);
    setState(() {});
  }
}
