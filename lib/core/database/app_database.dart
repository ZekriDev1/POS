import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:restropos/core/database/tables/products_table.dart';
import 'package:restropos/core/database/tables/categories_table.dart';
import 'package:restropos/core/database/tables/customers_table.dart';
import 'package:restropos/core/database/tables/sales_table.dart';
import 'package:restropos/core/database/tables/sale_items_table.dart';
import 'package:restropos/core/database/tables/suppliers_table.dart';
import 'package:restropos/core/database/tables/inventory_history_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Categories,
    Customers,
    Sales,
    SaleItems,
    Suppliers,
    InventoryHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(categories, categories.icon);
        await m.addColumn(categories, categories.parentId);
      }
    },
  );

  // ── Products ──
  Future<List<Product>> getAllProducts() => select(products).get();

  Future<List<Product>> searchProducts(String q) {
    final pattern = '%$q%';
    return (select(products)..where((p) => p.name.like(pattern) | p.barcode.like(pattern))).get();
  }

  Future<List<Product>> getProductsByCategory(String categoryId) {
    return (select(products)..where((p) => p.categoryId.equals(categoryId))).get();
  }

  Future<List<Product>> getLowStockProducts(int threshold) {
    return (select(products)..where((p) => p.quantity.isSmallerThan(Constant(threshold)))).get();
  }

  Future<Product?> getProductById(String id) {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<Product?> getProductByBarcode(String barcode) {
    return (select(products)..where((p) => p.barcode.equals(barcode))).getSingleOrNull();
  }

  Future<int> getProductCount() =>
      (select(products)..where((t) => t.id.isNotNull())).get().then((r) => r.length);

  Future<void> createProduct({
    required String id,
    String? barcode,
    required String name,
    String? description,
    String? image,
    String? categoryId,
    double? costPrice,
    required double sellingPrice,
    int quantity = 0,
  }) async {
    await into(products).insert(ProductsCompanion(
      id: Value(id),
      barcode: Value(barcode),
      name: Value(name),
      description: Value(description),
      image: Value(image),
      categoryId: Value(categoryId),
      costPrice: Value(costPrice),
      sellingPrice: Value(sellingPrice),
      quantity: Value(quantity),
      createdAt: Value(DateTime.now()),
    ));
  }

  Future<void> updateProductFields({
    required String id,
    String? barcode,
    String? name,
    String? description,
    String? image,
    String? categoryId,
    double? costPrice,
    double? sellingPrice,
    int? quantity,
  }) async {
    await (update(products)..where((t) => t.id.equals(id))).write(ProductsCompanion(
      id: Value(id),
      barcode: barcode != null ? Value(barcode) : const Value.absent(),
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      image: image != null ? Value(image) : const Value.absent(),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      costPrice: costPrice != null ? Value(costPrice) : const Value.absent(),
      sellingPrice: sellingPrice != null ? Value(sellingPrice) : const Value.absent(),
      quantity: quantity != null ? Value(quantity) : const Value.absent(),
    ));
  }

  Future<void> updateProductStock(String id, int newQuantity) async {
    await (update(products)..where((t) => t.id.equals(id))).write(ProductsCompanion(
      id: Value(id),
      quantity: Value(newQuantity),
    ));
  }

  Future<int> deleteProduct(String id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  // ── Categories ──
  Future<List<Category>> getAllCategories() => select(categories).get();

  Future<void> createCategory(String id, String name) async {
    await into(categories).insert(CategoriesCompanion(id: Value(id), name: Value(name)));
  }

  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Future<int> getCategoryCount() =>
      (select(categories)..where((t) => t.id.isNotNull())).get().then((r) => r.length);

  // ── Customers ──
  Future<List<Customer>> getAllCustomers() => select(customers).get();

  Future<Customer?> getCustomerById(String id) {
    return (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<void> createCustomer(String id, String name, String? phone, String? email) async {
    await into(customers).insert(CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      email: Value(email),
    ));
  }

  Future<int> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  // ── Sales ──
  Future<List<Sale>> getAllSales() => select(sales).get();

  Future<Sale?> getSaleById(String id) {
    return (select(sales)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> createSale({
    required String id,
    required String invoiceNumber,
    String? customerId,
    required double subtotal,
    required double total,
    required String paymentMethod,
    DateTime? createdAt,
  }) async {
    await into(sales).insert(SalesCompanion(
      id: Value(id),
      invoiceNumber: Value(invoiceNumber),
      customerId: Value(customerId),
      subtotal: Value(subtotal),
      total: Value(total),
      paymentMethod: Value(paymentMethod),
      createdAt: Value(createdAt ?? DateTime.now()),
    ));
  }

  Future<int> getTodaySaleCount() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (select(sales)..where((s) => s.createdAt.isBetweenValues(start, end)))
        .get()
        .then((r) => r.length);
  }

  Future<double> getTodayRevenue() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (select(sales)..where((s) => s.createdAt.isBetweenValues(start, end)))
        .get()
        .then((r) => r.fold<double>(0, (sum, s) => sum + s.total));
  }

  Future<double> getMonthlyRevenue() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return (select(sales)..where((s) => s.createdAt.isBetweenValues(start, end)))
        .get()
        .then((r) => r.fold<double>(0, (sum, s) => sum + s.total));
  }

  Future<double> getTotalRevenue() {
    return (select(sales)..where((s) => s.id.isNotNull()))
        .get()
        .then((r) => r.fold<double>(0, (sum, s) => sum + s.total));
  }

  // ── Sale Items ──
  Future<List<SaleItem>> getSaleItems(String saleId) {
    return (select(saleItems)..where((i) => i.saleId.equals(saleId))).get();
  }

  Future<void> createSaleItem({
    required String id,
    required String saleId,
    required String productId,
    required int quantity,
    required double price,
  }) async {
    await into(saleItems).insert(SaleItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      productId: Value(productId),
      quantity: Value(quantity),
      price: Value(price),
    ));
  }

  Future<int> getTotalItemsSold() {
    return (select(saleItems)..where((i) => i.id.isNotNull()))
        .get()
        .then((r) => r.fold<int>(0, (sum, i) => sum + i.quantity));
  }

  Future<void> deleteSale(String id) async {
    await (delete(saleItems)..where((i) => i.saleId.equals(id))).go();
    await (delete(sales)..where((s) => s.id.equals(id))).go();
  }

  // ── Suppliers ──
  Future<List<Supplier>> getAllSuppliers() => select(suppliers).get();

  Future<void> createSupplier(String id, String name, String? phone, String? email) async {
    await into(suppliers).insert(SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      email: Value(email),
    ));
  }

  Future<int> deleteSupplier(String id) =>
      (delete(suppliers)..where((t) => t.id.equals(id))).go();

  // ── Inventory History ──
  Future<List<InventoryHistoryData>> getInventoryHistory() => select(inventoryHistory).get();

  Future<List<InventoryHistoryData>> getInventoryHistoryForProduct(String productId) {
    return (select(inventoryHistory)..where((h) => h.productId.equals(productId))).get();
  }

  Future<void> createInventoryEntry({
    required String id,
    required String productId,
    required int quantity,
    required String type,
    DateTime? date,
  }) async {
    await into(inventoryHistory).insert(InventoryHistoryCompanion(
      id: Value(id),
      productId: Value(productId),
      quantity: Value(quantity),
      type: Value(type),
      date: Value(date ?? DateTime.now()),
    ));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    await Directory(dir.path).create(recursive: true);
    final file = File(p.join(dir.path, 'restropos.db'));
    return NativeDatabase(file, logStatements: true);
  });
}
