import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildCategories(),
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
          hintText: 'Search category or product...',
          hintStyle: const TextStyle(color: AppTheme.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
          filled: true, fillColor: AppTheme.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategories() {
    return FutureBuilder(
      future: ref.read(databaseProvider).getAllCategories(),
      builder: (ctx, snap) {
        final cats = snap.data ?? [];
        return SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCatCard('All', null, Icons.grid_view),
              ...cats.map((c) => _buildCatCard(c.name, c.id, Icons.category)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatCard(String label, String? id, IconData icon) {
    final active = _selectedCategory == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: Container(
        width: 80, height: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.1) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppTheme.primary : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? AppTheme.primary : AppTheme.textMuted, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: active ? AppTheme.primary : AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
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
            Text('Add Product', style: TextStyle(
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
                      title: const Text('Delete Product'),
                      content: Text('Are you sure you want to delete "${product.name}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
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
              child: const Text('Add to Billing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
