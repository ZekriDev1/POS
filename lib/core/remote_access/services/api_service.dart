import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:restropos/core/remote_access/database/remote_access_db.dart';
import 'package:restropos/core/remote_access/services/auth_service.dart';
import 'package:restropos/core/remote_access/models/remote_access_models.dart';

class ApiService {
  final AuthService _auth;
  final RemoteAccessTables _db;
  final Router _router = Router();
  final List<WebSocketChannel> _wsClients = [];

  ApiService(this._auth, this._db) {
    _setupRoutes();
  }

  Router get router => _router;
  List<WebSocketChannel> get wsClients => _wsClients;

  void _setupRoutes() {
    _router.get('/ping', _handlePing);
    _router.post('/login', _handleLogin);
    _router.post('/logout', _handleLogout);
    _router.post('/refresh', _handleRefresh);
    _router.get('/me', _authenticated(_handleMe));
    _router.get('/products', _authenticated(_handleGetProducts));
    _router.get('/products/search', _authenticated(_handleSearchProducts));
    _router.get('/products/:id', _authenticated(_handleGetProduct));
    _router.post('/sales', _authenticated(_handleCreateSale, requiredRole: UserRole.cashier));
    _router.get('/categories', _authenticated(_handleGetCategories));
    _router.get('/customers', _authenticated(_handleGetCustomers));
    _router.get('/suppliers', _authenticated(_handleGetSuppliers));
    _router.get('/sales', _authenticated(_handleGetSales));
    _router.get('/sales/:id', _authenticated(_handleGetSale));
    _router.get('/dashboard', _authenticated(_handleDashboard));
    _router.get('/reports/sales', _authenticated(_handleSalesReport));
    _router.get('/inventory', _authenticated(_handleInventory));
    _router.get('/sessions', _authenticated(_handleGetSessions, requiredRole: UserRole.administrator));
    _router.post('/sessions/:id/disconnect', _authenticated(_handleDisconnectSession, requiredRole: UserRole.administrator));
    _router.get('/audit-logs', _authenticated(_handleAuditLogs, requiredRole: UserRole.administrator));
  }

  Handler _authenticated(Future<Response> Function(Request, RemoteUser) handler, {UserRole? requiredRole}) {
    return (Request request) async {
      final auth = request.headers['authorization'];
      if (auth == null || !auth.startsWith('Bearer ')) {
        return Response(401, body: json.encode({'error': 'Missing token'}));
      }
      final token = auth.substring(7);
      final user = await _auth.validateToken(token);
      if (user == null) {
        return Response(401, body: json.encode({'error': 'Invalid or expired token'}));
      }
      if (requiredRole != null && !_auth.hasPermission(user, requiredRole)) {
        return Response(403, body: json.encode({'error': 'Insufficient permissions'}));
      }
      return handler(request, user);
    };
  }

  Future<Response> _handlePing(Request request) async {
    return Response.ok(json.encode({'ok': true, 'time': DateTime.now().toIso8601String()}),
        headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleLogin(Request request) async {
    try {
      final body = json.decode(await request.readAsString()) as Map<String, dynamic>;
      final result = await _auth.login(
        body['username']?.toString() ?? '',
        body['password']?.toString() ?? '',
        device: body['device']?.toString() ?? '',
        browser: body['browser']?.toString() ?? '',
        ipAddress: request.headers['x-forwarded-for']?.split(',').first.trim() ?? 'local',
      );
      return Response.ok(json.encode({
        'success': result.success,
        if (result.token != null) 'token': result.token,
        if (result.refreshToken != null) 'refreshToken': result.refreshToken,
        if (result.user != null) 'user': _userToJson(result.user!),
        if (result.error != null) 'error': result.error,
      }), headers: {'content-type': 'application/json'});
    } catch (_) {
      return Response(400, body: json.encode({'error': 'Invalid request'}));
    }
  }

  Future<Response> _handleLogout(Request request, RemoteUser user) async {
    final auth = request.headers['authorization'] ?? '';
    final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
    String? rt;
    try {
      final body = json.decode(await request.readAsString()) as Map<String, dynamic>;
      rt = body['refreshToken']?.toString();
    } catch (_) {}
    await _auth.logout(token, rt);
    return Response.ok(json.encode({'success': true}));
  }

  Future<Response> _handleRefresh(Request request) async {
    try {
      final body = json.decode(await request.readAsString()) as Map<String, dynamic>;
      final result = await _auth.refreshToken(body['refreshToken']?.toString() ?? '');
      return Response.ok(json.encode({
        'success': result.success,
        if (result.token != null) 'token': result.token,
        if (result.refreshToken != null) 'refreshToken': result.refreshToken,
        if (result.error != null) 'error': result.error,
      }), headers: {'content-type': 'application/json'});
    } catch (_) {
      return Response(400, body: json.encode({'error': 'Invalid request'}));
    }
  }

  Future<Response> _handleMe(Request request, RemoteUser user) async {
    return Response.ok(json.encode({'user': _userToJson(user)}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetProducts(Request request, RemoteUser user) async {
    final products = await _db.getAllProductsRaw();
    return Response.ok(json.encode({'products': products}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleSearchProducts(Request request, RemoteUser user) async {
    final q = request.url.queryParameters['q'] ?? '';
    if (q.isEmpty) return _handleGetProducts(request, user);
    final products = await _db.searchProductsRaw(q);
    return Response.ok(json.encode({'products': products}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetProduct(Request request, RemoteUser user) async {
    final id = request.params['id'] ?? '';
    final product = await _db.getProductByIdRaw(id);
    if (product == null) return Response(404, body: json.encode({'error': 'Not found'}));
    return Response.ok(json.encode({'product': product}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetCategories(Request request, RemoteUser user) async {
    final categories = await _db.getAllCategoriesRaw();
    return Response.ok(json.encode({'categories': categories}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetCustomers(Request request, RemoteUser user) async {
    final customers = await _db.getAllCustomersRaw();
    return Response.ok(json.encode({'customers': customers}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetSuppliers(Request request, RemoteUser user) async {
    final suppliers = await _db.getAllSuppliersRaw();
    return Response.ok(json.encode({'suppliers': suppliers}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetSales(Request request, RemoteUser user) async {
    final sales = await _db.getAllSalesRaw();
    return Response.ok(json.encode({'sales': sales}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetSale(Request request, RemoteUser user) async {
    final id = request.params['id'] ?? '';
    final sale = await _db.getSaleWithItemsRaw(id);
    if (sale == null) return Response(404, body: json.encode({'error': 'Not found'}));
    return Response.ok(json.encode({'sale': sale}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleDashboard(Request request, RemoteUser user) async {
    final stats = await _db.getDashboardStatsRaw();
    return Response.ok(json.encode({'stats': stats}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleCreateSale(Request request, RemoteUser user) async {
    try {
      final body = json.decode(await request.readAsString()) as Map<String, dynamic>;
      final sale = await _db.createSaleRaw(body);
      return Response.ok(json.encode({'sale': sale}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(400, body: json.encode({'error': 'Failed to create sale: $e'}));
    }
  }

  Future<Response> _handleSalesReport(Request request, RemoteUser user) async {
    final period = request.url.queryParameters['period'] ?? 'today';
    final report = await _db.getSalesReportRaw(period);
    return Response.ok(json.encode({'report': report}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleInventory(Request request, RemoteUser user) async {
    final inv = await _db.getInventoryRaw();
    return Response.ok(json.encode({'inventory': inv}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetSessions(Request request, RemoteUser user) async {
    final sessions = await _db.getActiveSessions();
    return Response.ok(json.encode({
      'sessions': sessions.map((s) => {
        'id': s.id, 'username': s.username, 'role': s.role.name,
        'device': s.device, 'browser': s.browser, 'ipAddress': s.ipAddress,
        'country': s.country, 'loginTime': s.loginTime.toIso8601String(),
        'lastActivity': s.lastActivity.toIso8601String(),
        'duration': s.duration.inSeconds,
      }).toList(),
    }), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleDisconnectSession(Request request, RemoteUser user) async {
    final sid = request.params['id'] ?? '';
    await _auth.disconnectSession(sid);
    _broadcast({'type': 'session_disconnected', 'sessionId': sid});
    return Response.ok(json.encode({'success': true}));
  }

  Future<Response> _handleAuditLogs(Request request, RemoteUser user) async {
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;
    final offset = int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;
    final logs = await _db.getAuditLogs(limit: limit, offset: offset);
    return Response.ok(json.encode({
      'logs': logs.map((l) => {
        'id': l.id, 'userId': l.userId, 'username': l.username, 'action': l.action,
        'details': l.details, 'ipAddress': l.ipAddress, 'timestamp': l.timestamp.toIso8601String(),
      }).toList(),
    }), headers: {'content-type': 'application/json'});
  }

  void broadcast(Map<String, dynamic> event) => _broadcast(event);

  void _broadcast(Map<String, dynamic> event) {
    final msg = json.encode(event);
    final dead = <int>[];
    for (int i = 0; i < _wsClients.length; i++) {
      try {
        _wsClients[i].sink.add(msg);
      } catch (_) {
        dead.add(i);
      }
    }
    for (final i in dead.reversed) {
      _wsClients.removeAt(i);
    }
  }

  Map<String, dynamic> _userToJson(RemoteUser u) => {
    'id': u.id, 'username': u.username, 'role': u.role.name, 'isActive': u.isActive,
  };
}
