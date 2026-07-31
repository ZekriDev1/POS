import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/l10n/translations.dart';

final _categoryIcons = {
  'category': Icons.category,
  'food': Icons.restaurant,
  'drink': Icons.local_drink,
  'coffee': Icons.coffee,
  'fastfood': Icons.fastfood,
  'cake': Icons.cake,
  'icecream': Icons.icecream,
  'fruit': Icons.apple,
  'bread': Icons.bakery_dining,
  'snack': Icons.shopping_bag,
  'tool': Icons.build,
  'electronic': Icons.electrical_services,
  'clothing': Icons.checkroom,
  'book': Icons.book,
  'gift': Icons.card_giftcard,
  'home': Icons.home,
  'beauty': Icons.spa,
  'sports': Icons.sports_soccer,
  'pet': Icons.pets,
  'other': Icons.more_horiz,
};

IconData _iconData(String? icon) => _categoryIcons[icon] ?? Icons.category;

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(ref.t('categories'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ElevatedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add, size: 18),
              label: Text(ref.t('addCategory')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          FutureBuilder(
            future: ref.read(databaseProvider).getParentCategories(),
            builder: (ctx, snap) {
              final cats = snap.data ?? <Category>[];
              if (cats.isEmpty) {
                return Center(child: Container(
                  padding: const EdgeInsets.all(40),
                  child: Text(ref.t('noCategories'), style: const TextStyle(color: AppTheme.textMuted)),
                ));
              }
              return Column(children: cats.map((c) => _buildCategoryTile(c)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Category cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_iconData(cat.icon), size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: () => _addSubCategory(cat),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _editCategory(cat),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deleteCategory(cat.id),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete, size: 16, color: Colors.red),
                ),
              ),
            ]),
          ),
          FutureBuilder(
            future: ref.read(databaseProvider).getSubCategories(cat.id),
            builder: (ctx, snap) {
              final subs = snap.data ?? <Category>[];
              if (subs.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: Column(children: subs.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(_iconData(s.icon), size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _editCategory(s),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit, size: 14, color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _deleteCategory(s.id),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 14, color: AppTheme.textMuted),
                      ),
                    ),
                  ]),
                )).toList()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({Category? existing, String? initialParentId}) {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    String? selectedIcon = existing?.icon;
    String? selectedParent = existing?.parentId ?? initialParentId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing != null ? ref.t('editCategory') : ref.t('addCategory')),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: ref.t('categoryName'),
                    filled: true, fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text(ref.t('icon'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _categoryIcons.entries.map((e) {
                  final active = selectedIcon == e.key;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = e.key),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary.withOpacity(0.1) : AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? AppTheme.primary : Colors.transparent, width: 2),
                      ),
                      child: Icon(e.value, size: 20, color: active ? AppTheme.primary : AppTheme.textMuted),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),
                Text(ref.t('parentCategory'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: ref.read(databaseProvider).getParentCategories(),
                  builder: (ctx, snap) {
                    final parents = snap.data ?? <Category>[];
                    return DropdownButtonFormField<String?>(
                      value: selectedParent,
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(ref.t('noneTop'))),
                        ...parents.where((p) => p.id != existing?.id).map((p) =>
                          DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => selectedParent = v),
                      decoration: const InputDecoration(
                        filled: true, fillColor: AppTheme.bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.t('cancel'))),
          TextButton(onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            final db = ref.read(databaseProvider);
            if (existing != null) {
              await db.updateCategory(id: existing.id, name: ctrl.text.trim(), icon: selectedIcon, parentId: selectedParent);
            } else {
              await db.createCategory(
                id: 'cat${DateTime.now().millisecondsSinceEpoch}',
                name: ctrl.text.trim(),
                icon: selectedIcon,
                parentId: selectedParent,
              );
            }
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {});
          }, child: Text(existing != null ? ref.t('save') : ref.t('addCategory'))),
        ],
      ),
    ));
  }

  void _addCategory() => _showCategoryDialog();
  void _addSubCategory(Category parent) => _showCategoryDialog(initialParentId: parent.id);
  void _editCategory(Category cat) => _showCategoryDialog(existing: cat);

  void _deleteCategory(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('deleteCategory')),
        content: Text(ref.t('deleteCategoryConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ref.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(ref.t('delete'))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteCategory(id);
      setState(() {});
    }
  }
}
