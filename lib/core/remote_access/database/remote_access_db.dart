import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/remote_access/models/remote_access_models.dart';

class RemoteAccessTables {
  final AppDatabase _db;
  RemoteAccessTables(this._db);

  Future<void> ensureSchema() async {
    await _db.rawExecute('''
      CREATE TABLE IF NOT EXISTS remote_users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await _db.rawExecute('''
      CREATE TABLE IF NOT EXISTS user_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        role TEXT NOT NULL,
        device TEXT NOT NULL DEFAULT '',
        browser TEXT NOT NULL DEFAULT '',
        ip_address TEXT NOT NULL DEFAULT '',
        country TEXT,
        login_time TEXT NOT NULL,
        last_activity TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES remote_users(id)
      )
    ''');
    await _db.rawExecute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        ip_address TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL
      )
    ''');

    final count = await _db.rawQuerySingle('SELECT COUNT(*) as c FROM remote_users');
    if (count != null && (count['c'] as int) == 0) {
      final hash = _hashPassword('admin123');
      await _db.rawExecute('''
        INSERT INTO remote_users (id, username, password_hash, role, is_active, created_at)
        VALUES (?, ?, ?, 'administrator', 1, ?)
      ''', variables: [_uuid(), 'admin', hash, DateTime.now().toIso8601String()]);
    }
  }

  Future<RemoteUser?> authenticate(String username, String password) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM remote_users WHERE username = ? AND is_active = 1',
      variables: [username],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final stored = row['password_hash'] as String;
    final parts = stored.split(':');
    if (parts.length != 2) return null;
    if (_sha256('$password:${parts[0]}') != parts[1]) return null;
    return _rowToUser(row);
  }

  Future<RemoteUser?> getUserById(String id) async {
    final rows = await _db.rawQuery('SELECT * FROM remote_users WHERE id = ?', variables: [id]);
    if (rows.isEmpty) return null;
    return _rowToUser(rows.first);
  }

  Future<String> createSession(String userId, String username, String role, {
    String device = '', String browser = '', String ipAddress = '', String? country,
  }) async {
    final id = _uuid();
    final now = DateTime.now().toIso8601String();
    await _db.rawExecute('''
      INSERT INTO user_sessions (id, user_id, username, role, device, browser, ip_address, country, login_time, last_activity, is_active)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    ''', variables: [id, userId, username, role, device, browser, ipAddress, country ?? '', now, now]);
    return id;
  }

  Future<void> touchSession(String sessionId) async {
    await _db.rawExecute('UPDATE user_sessions SET last_activity = ? WHERE id = ?',
        variables: [DateTime.now().toIso8601String(), sessionId]);
  }

  Future<void> endSession(String sessionId) async {
    await _db.rawExecute('UPDATE user_sessions SET is_active = 0 WHERE id = ?', variables: [sessionId]);
  }

  Future<void> endAllSessions() async {
    await _db.rawExecute('UPDATE user_sessions SET is_active = 0 WHERE is_active = 1');
  }

  Future<List<UserSession>> getActiveSessions() async {
    final rows = await _db.rawQuery(
      'SELECT * FROM user_sessions WHERE is_active = 1 ORDER BY login_time DESC',
    );
    return rows.map((d) {
      return UserSession(
        id: d['id'] as String,
        userId: d['user_id'] as String,
        username: d['username'] as String,
        role: UserRole.values.firstWhere((e) => e.name == d['role']),
        device: d['device'] as String? ?? '',
        browser: d['browser'] as String? ?? '',
        ipAddress: d['ip_address'] as String? ?? '',
        country: d['country'] as String?,
        loginTime: DateTime.parse(d['login_time'] as String),
        lastActivity: DateTime.parse(d['last_activity'] as String),
      );
    }).toList();
  }

  Future<int> getActiveUserCount() async {
    final row = await _db.rawQuerySingle(
      'SELECT COUNT(DISTINCT user_id) as c FROM user_sessions WHERE is_active = 1',
    );
    return (row?['c'] as int?) ?? 0;
  }

  Future<void> logAudit(String userId, String username, String action, String? details, String ipAddress) async {
    await _db.rawExecute('''
      INSERT INTO audit_logs (user_id, username, action, details, ip_address, timestamp)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', variables: [userId, username, action, details ?? '', ipAddress, DateTime.now().toIso8601String()]);
  }

  Future<List<AuditLog>> getAuditLogs({int limit = 100, int offset = 0}) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT ? OFFSET ?',
      variables: [limit, offset],
    );
    return rows.map((d) {
      return AuditLog(
        id: d['id'] as int,
        userId: d['user_id'] as String,
        username: d['username'] as String,
        action: d['action'] as String,
        details: d['details'] as String?,
        ipAddress: d['ip_address'] as String? ?? '',
        timestamp: DateTime.parse(d['timestamp'] as String),
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllProductsRaw() async {
    return _db.rawQuery('SELECT * FROM products ORDER BY name');
  }

  Future<List<Map<String, dynamic>>> searchProductsRaw(String query) async {
    return _db.rawQuery(
      'SELECT * FROM products WHERE name LIKE ? OR barcode LIKE ? ORDER BY name',
      variables: ['%$query%', '%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> getProductsByCategoryRaw(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty || categoryId == 'all') {
      return _db.rawQuery('SELECT * FROM products ORDER BY name');
    }
    return _db.rawQuery(
      'SELECT * FROM products WHERE category_id = ? ORDER BY name', variables: [categoryId]);
  }

  Future<Map<String, dynamic>?> getProductByIdRaw(String id) async {
    return _db.rawQuerySingle('SELECT * FROM products WHERE id = ?', variables: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllCategoriesRaw() async {
    return _db.rawQuery('SELECT * FROM categories ORDER BY name');
  }

  Future<List<Map<String, dynamic>>> getAllCustomersRaw() async {
    return _db.rawQuery('SELECT * FROM customers ORDER BY name');
  }

  Future<List<Map<String, dynamic>>> getAllSuppliersRaw() async {
    return _db.rawQuery('SELECT * FROM suppliers ORDER BY name');
  }

  Future<List<Map<String, dynamic>>> getAllSalesRaw() async {
    final rows = await _db.rawQuery('SELECT * FROM sales ORDER BY created_at DESC');
    return rows.map((d) {
      final m = Map<String, dynamic>.from(d);
      final ca = m['created_at'];
      if (ca is DateTime) m['created_at'] = ca.toIso8601String();
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> getSaleWithItemsRaw(String id) async {
    final sale = await _db.rawQuerySingle('SELECT * FROM sales WHERE id = ?', variables: [id]);
    if (sale == null) return null;
    final items = await _db.rawQuery('SELECT * FROM sale_items WHERE sale_id = ?', variables: [id]);
    sale['items'] = items;
    return sale;
  }

  Future<Map<String, dynamic>> getDashboardStatsRaw() async {
    try {
      final products = (await _db.rawQuerySingle('SELECT COUNT(*) as c FROM products'))?['c'] ?? 0;
      final categories = (await _db.rawQuerySingle('SELECT COUNT(*) as c FROM categories'))?['c'] ?? 0;
      num todaySales = 0;
      try {
        todaySales = (await _db.rawQuerySingle(
          'SELECT COALESCE(SUM(total), 0) as s FROM sales WHERE created_at >= ?',
          variables: ['${DateTime.now().toIso8601String().substring(0, 10)}T00:00:00'],
        ))?['s'] ?? 0;
      } catch (_) {}
      final totalOrders = (await _db.rawQuerySingle('SELECT COUNT(*) as c FROM sales'))?['c'] ?? 0;
      return {'products': products, 'categories': categories, 'todaySales': todaySales, 'totalOrders': totalOrders};
    } catch (_) {
      return {'products': 0, 'categories': 0, 'todaySales': 0, 'totalOrders': 0};
    }
  }

  Future<Map<String, dynamic>> getSalesReportRaw(String period) async {
    DateTime start;
    switch (period) {
      case 'week': start = DateTime.now().subtract(const Duration(days: 7)); break;
      case 'month': start = DateTime.now().subtract(const Duration(days: 30)); break;
      case 'year': start = DateTime.now().subtract(const Duration(days: 365)); break;
      default: start = DateTime.now().subtract(const Duration(days: 1)); break;
    }
    final row = await _db.rawQuerySingle(
      'SELECT COALESCE(SUM(total), 0) as total, COUNT(*) as count FROM sales WHERE created_at >= ?',
      variables: [start.toIso8601String()],
    );
    return row ?? {'total': 0, 'count': 0};
  }

  Future<List<RemoteUser>> getAllUsers() async {
    final rows = await _db.rawQuery('SELECT * FROM remote_users ORDER BY created_at ASC');
    return rows.map(_rowToUser).toList();
  }

  Future<String> createUser(String username, String password, String role) async {
    final id = _uuid();
    final hash = _hashPassword(password);
    await _db.rawExecute('''
      INSERT INTO remote_users (id, username, password_hash, role, is_active, created_at)
      VALUES (?, ?, ?, ?, 1, ?)
    ''', variables: [id, username, hash, role, DateTime.now().toIso8601String()]);
    return id;
  }

  Future<void> updateUserPassword(String id, String newPassword) async {
    final hash = _hashPassword(newPassword);
    await _db.rawExecute('UPDATE remote_users SET password_hash = ? WHERE id = ?',
        variables: [hash, id]);
  }

  Future<void> updateUserRole(String id, String role) async {
    await _db.rawExecute('UPDATE remote_users SET role = ? WHERE id = ?',
        variables: [role, id]);
  }

  Future<void> toggleUserActive(String id) async {
    await _db.rawExecute('UPDATE remote_users SET is_active = NOT is_active WHERE id = ?',
        variables: [id]);
  }

  Future<void> deleteUser(String id) async {
    await _db.rawExecute('DELETE FROM remote_users WHERE id = ?', variables: [id]);
    await _db.rawExecute('UPDATE user_sessions SET is_active = 0 WHERE user_id = ?', variables: [id]);
  }

  Future<Map<String, dynamic>> createSaleRaw(Map<String, dynamic> data) async {
    final saleId = _uuid();
    final now = DateTime.now().toIso8601String();
    final invoiceNum = 'WEB-${now.substring(0, 10).replaceAll('-', '')}-${saleId.substring(0, 4)}';
    final items = data['items'] as List<dynamic>;
    final subtotal = (data['subtotal'] as num).toDouble();
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    final tax = (data['tax'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num).toDouble();
    final paymentMethod = data['payment_method']?.toString() ?? 'cash';

    await _db.rawExecute('''
      INSERT INTO sales (id, invoice_number, subtotal, discount, tax, total, payment_method, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', variables: [saleId, invoiceNum, subtotal, discount, tax, total, paymentMethod, now]);

    for (final item in items) {
      final itemId = _uuid();
      final productId = item['id']?.toString() ?? item['product_id']?.toString() ?? '';
      final qty = (item['quantity'] as num).toInt();
      final price = (item['price'] as num?)?.toDouble() ?? (item['selling_price'] as num?)?.toDouble() ?? 0;
      await _db.rawExecute('''
        INSERT INTO sale_items (id, sale_id, product_id, quantity, price)
        VALUES (?, ?, ?, ?, ?)
      ''', variables: [itemId, saleId, productId, qty, price]);
      await _db.rawExecute('UPDATE products SET quantity = quantity - ? WHERE id = ?',
          variables: [qty, productId]);
    }

    final sale = await _db.rawQuerySingle('SELECT * FROM sales WHERE id = ?', variables: [saleId]);
    final saleItems = await _db.rawQuery('SELECT * FROM sale_items WHERE sale_id = ?', variables: [saleId]);
    if (sale != null) sale['items'] = saleItems;
    return sale ?? {};
  }

  Future<List<Map<String, dynamic>>> getInventoryRaw() async {
    return _db.rawQuery('SELECT id, name, quantity, selling_price FROM products ORDER BY name');
  }

  String _hashPassword(String password) {
    final salt = _generateSalt();
    return '$salt:${_sha256('$password:$salt')}';
  }

  String _generateSalt([int length = 16]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  RemoteUser _rowToUser(Map<String, dynamic> row) => RemoteUser(
    id: row['id'] as String,
    username: row['username'] as String,
    passwordHash: row['password_hash'] as String,
    role: UserRole.values.firstWhere((e) => e.name == row['role']),
    isActive: (row['is_active'] as int) == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  String _uuid() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return '${_hex(bytes, 0, 4)}-${_hex(bytes, 4, 2)}-${_hex(bytes, 6, 2)}-${_hex(bytes, 8, 2)}-${_hex(bytes, 10, 6)}';
  }
  String _hex(List<int> bytes, int start, int len) =>
      bytes.sublist(start, start + len).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
