import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/l10n/translations.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/utils/currency_formatter.dart';
import 'package:restropos/features/products/screens/product_form_screen.dart';

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

class CartState {
  final List<CartItem> items;
  final String paymentMethod;
  CartState({this.items = const [], this.paymentMethod = 'cash'});
  double get subtotal => items.fold(0, (s, i) => s + i.price * i.quantity);
  double get total => subtotal;
}

class CartItem {
  final String id;
  final String name;
  final String? image;
  final double price;
  final int quantity;
  CartItem({required this.id, required this.name, this.image, required this.price, this.quantity = 1});
  CartItem copyWith({int? quantity}) => CartItem(id: id, name: name, image: image, price: price, quantity: quantity ?? this.quantity);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addItem(String id, String name, String? image, double price, int stock) {
    final idx = state.items.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      final item = state.items[idx];
      if (item.quantity >= stock) return;
      final updated = [...state.items];
      updated[idx] = item.copyWith(quantity: item.quantity + 1);
      state = CartState(items: updated, paymentMethod: state.paymentMethod);
    } else {
      state = CartState(items: [...state.items, CartItem(id: id, name: name, image: image, price: price)], paymentMethod: state.paymentMethod);
    }
  }

  void updateQty(int index, int delta) {
    final items = [...state.items];
    final newQty = items[index].quantity + delta;
    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: newQty);
    }
    state = CartState(items: items, paymentMethod: state.paymentMethod);
  }

  void setPaymentMethod(String method) {
    state = CartState(items: state.items, paymentMethod: method);
  }

  void clear() => state = CartState();
}

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  String? _selectedParent;
  String? _hoveredCategoryId;
  String? _hoveredTagId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 24, end: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildCategoriesRow(),
                if (_selectedParent != null) ...[
                  const SizedBox(height: 8),
                  _buildSubCategoriesRow(),
                ],
                const SizedBox(height: 12),
                Expanded(child: _buildProductGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: context.t('searchHint'),
          hintStyle: const TextStyle(color: AppTheme.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
          filled: true, fillColor: AppTheme.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  static const _catIcons = <String, IconData>{
    'category': Icons.category, 'food': Icons.restaurant, 'drink': Icons.local_drink,
    'coffee': Icons.coffee, 'fastfood': Icons.fastfood, 'cake': Icons.cake,
    'icecream': Icons.icecream, 'fruit': Icons.apple, 'bread': Icons.bakery_dining,
    'snack': Icons.shopping_bag, 'tool': Icons.build, 'gift': Icons.card_giftcard,
    'other': Icons.more_horiz,
  };

  Widget _buildCategoriesRow() {
    return FutureBuilder(
      future: ref.read(databaseProvider).getParentCategories(),
      builder: (ctx, snap) {
        final cats = snap.data ?? <Category>[];
        return SizedBox(
          height: 80,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _buildCatCard(context.t('all'), null, Icons.grid_view, isParent: true),
            ...cats.map((c) => _buildCatCard(c.name, c.id, _catIcons[c.icon] ?? Icons.category, cat: c, isParent: true)),
          ]),
        );
      },
    );
  }

  Widget _buildSubCategoriesRow() {
    return FutureBuilder(
      future: ref.read(databaseProvider).getSubCategories(_selectedParent!),
      builder: (ctx, snap) {
        final subs = snap.data ?? <Category>[];
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                _buildTag(context.t('all'), null, isAll: true),
                ...subs.map((s) => _buildTag(s.name, s.id, icon: _catIcons[s.icon], cat: s)),
                _buildAddTag(),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String label, String? id, {IconData? icon, bool isAll = false, Category? cat}) {
    final active = id == null ? _selectedCategory == null : _selectedCategory == id;
    final editable = cat != null && !isAll;
    final hovered = _hoveredTagId == id;

    final pill = Container(
      padding: EdgeInsets.only(left: 14, right: hovered ? 6 : 14, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppTheme.primary : AppTheme.textMuted.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isAll) ...[
          Icon(Icons.arrow_back, size: 14, color: active ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 4),
        ],
        if (icon != null) ...[
          Icon(icon, size: 14, color: active ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : AppTheme.textMain, fontWeight: FontWeight.w500)),
        if (editable) ...[
          const SizedBox(width: 4),
          AnimatedOpacity(
            opacity: hovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTap: () {
                _hoveredTagId = null;
                _renameSubCategory(cat);
              },
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.25) : AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.edit, size: 11, color: active ? Colors.white : AppTheme.primary),
              ),
            ),
          ),
        ],
      ]),
    );

    if (!editable) {
      return GestureDetector(
        onTap: () => setState(() => _selectedCategory = id),
        child: pill,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTagId = id),
      onExit: (_) => setState(() => _hoveredTagId = null),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = id),
        child: pill,
      ),
    );
  }

  void _renameSubCategory(Category cat) async {
    final nameCtrl = TextEditingController(text: cat.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ref.t('renameSubCategory')),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: ref.t('name'),
            filled: true, fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: Text(ref.t('save'))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != cat.name) {
      await ref.read(databaseProvider).updateCategory(id: cat.id, name: newName, icon: cat.icon, parentId: cat.parentId);
      setState(() {});
    }
  }

  Widget _buildAddTag() {
    return GestureDetector(
      onTap: _quickAddSubCategory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(ref.t('add'), style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  void _quickAddSubCategory() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ref.t('newSubCategory')),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: ref.t('subCategoryName'),
            filled: true, fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: Text(ref.t('add'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && _selectedParent != null) {
      await ref.read(databaseProvider).createCategory(
        id: 'cat${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        icon: null,
        parentId: _selectedParent,
      );
      setState(() {});
    }
  }

  Widget _buildCatCard(String label, String? id, IconData icon, {Category? cat, bool isParent = false, bool isSubAll = false}) {
    final active = isParent ? _selectedParent == id && _selectedCategory == null
        : id == null ? _selectedParent != null && _selectedCategory == null
        : _selectedCategory == id;
    final card = Container(
      width: isParent ? 80.0 : 68.0,
      height: isParent ? 80.0 : 60.0,
      margin: const EdgeInsetsDirectional.only(end: 10),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary.withOpacity(0.1) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(isParent ? 20 : 16),
        border: Border.all(color: active ? AppTheme.primary : Colors.transparent, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? AppTheme.primary : AppTheme.textMuted, size: isParent ? 24 : 20),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(label, style: TextStyle(fontSize: isParent ? 11 : 10, color: active ? AppTheme.primary : AppTheme.textMuted, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    if (cat == null || id == null) {
      return GestureDetector(onTap: () => setState(() {
        _selectedCategory = null;
        _selectedParent = null;
      }), child: card);
    }

    if (isParent) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hoveredCategoryId = id),
        onExit: (_) => setState(() => _hoveredCategoryId = null),
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedParent = id;
            _selectedCategory = null;
          }),
          onLongPress: () => _showCatMenu(cat),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                top: -4, right: -4,
                child: AnimatedOpacity(
                  opacity: _hoveredCategoryId == id ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    onTap: () {
                      _hoveredCategoryId = null;
                      _editCategory(cat);
                    },
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 1),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      child: Icon(Icons.edit, size: 13, color: AppTheme.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isSubAll) {
      return GestureDetector(
        onTap: () => setState(() {
          _selectedCategory = null;
        }),
        child: card,
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: card,
    );
  }

  void _showCatMenu(Category cat) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.edit, color: AppTheme.primary), title: Text(ref.t('editCategory')), onTap: () => Navigator.pop(ctx, 'edit')),
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(ref.t('deleteCategory'), style: const TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx, 'delete')),
          ]),
        ),
      ),
    );
    if (result == 'edit') _editCategory(cat);
    if (result == 'delete') _deleteCategory(cat);
  }

  void _editCategory(Category cat) async {
    final nameCtrl = TextEditingController(text: cat.name);
    String? icon = cat.icon;
    String? parentId = cat.parentId;
    final db = ref.read(databaseProvider);
    final parents = await db.getParentCategories();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ref.t('editCategory')),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: ref.t('categoryName'),
                    filled: true, fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text(ref.t('parentCategory'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: parentId,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(ref.t('noneTop'))),
                    ...parents.where((p) => p.id != cat.id).map((p) =>
                      DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => parentId = v),
                  decoration: const InputDecoration(
                    filled: true, fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text(ref.t('icon'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _catIcons.entries.map((e) {
                  final active = icon == e.key;
                  return GestureDetector(
                    onTap: () => setDialogState(() => icon = e.key),
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
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.t('cancel'))),
            TextButton(onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await db.updateCategory(id: cat.id, name: nameCtrl.text.trim(), icon: icon, parentId: parentId);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            }, child: Text(ref.t('saveChanges'))),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(Category cat) async {
    final db = ref.read(databaseProvider);
    final subCount = (await db.getSubCategories(cat.id)).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ref.t('deleteCategory')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ref.t('deleteCategoryMsg', {'name': cat.name})),
          const SizedBox(height: 8),
          Text(ref.t('uncategorizeWarning'), style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          if (subCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              ref.t(subCount == 1 ? 'subCatDeletedOne' : 'subCatsDeletedMany', {'count': '$subCount'}),
              style: TextStyle(fontSize: 13, color: Colors.red.shade400),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ref.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(ref.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.uncategorizeProductsByCategory(cat.id);
      await db.deleteCategory(cat.id);
      if (_selectedParent == cat.id || _selectedCategory == cat.id) {
        _selectedParent = null;
        _selectedCategory = null;
      }
      setState(() {});
    }
  }

  Widget _buildProductGrid() {
    final db = ref.read(databaseProvider);
    final query = _searchCtrl.text;
    return FutureBuilder(
      future: _loadProducts(db, query),
      builder: (ctx, snap) {
        final products = snap.data ?? [];
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) return _buildAddCard();
            return _buildProductCard(products[i - 1]);
          },
        );
      },
    );
  }

  Future<List<dynamic>> _loadProducts(AppDatabase db, String query) async {
    if (query.isNotEmpty) return db.searchProducts(query);
    if (_selectedCategory != null) return db.getProductsByCategory(_selectedCategory!);
    if (_selectedParent != null) {
      final subs = await db.getSubCategories(_selectedParent!);
      final ids = [_selectedParent!, ...subs.map((s) => s.id)];
      return db.getProductsByCategories(ids);
    }
    return db.getAllProducts();
  }

  Widget _buildProductInitial(dynamic product) {
    return Center(child: Text(product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primary)));
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        );
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(context.t('addProduct'), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
                  );
                  setState(() {});
                },
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.t('deleteProduct')),
                      content: Text(context.t('deleteProductConfirm', {'name': product.name})),
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
                    await ref.read(databaseProvider).deleteProduct(product.id);
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
            ],
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.image != null
                      ? Image.file(File(product.image!), fit: BoxFit.cover, width: 72, height: 72, errorBuilder: (_, __, ___) => _buildProductInitial(product))
                      : _buildProductInitial(product),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(CurrencyFormatter.format(product.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(cartProvider.notifier).addItem(product.id, product.name, product.image, product.sellingPrice, product.quantity);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(context.t('addToBilling'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
