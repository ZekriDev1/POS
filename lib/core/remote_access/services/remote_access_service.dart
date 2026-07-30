import 'dart:async';
import 'dart:convert';
import 'dart:io' hide WebSocket;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/remote_access/database/remote_access_db.dart';
import 'package:restropos/core/remote_access/services/auth_service.dart';
import 'package:restropos/core/remote_access/services/api_service.dart';
import 'package:restropos/core/remote_access/services/cloudflare_tunnel_service.dart';
import 'package:restropos/core/remote_access/models/remote_access_models.dart';

class RemoteAccessService {
  final AppDatabase _appDb;
  late final RemoteAccessTables _tables;
  late final AuthService _auth;
  late final ApiService _api;
  late final CloudflareTunnelService _tunnel;
  HttpServer? _httpServer;
  bool _initialized = false;

  RemoteAccessState _state = const RemoteAccessState();
  final _stateController = StreamController<RemoteAccessState>.broadcast();

  RemoteAccessService(this._appDb) {
    _tables = RemoteAccessTables(_appDb);
    _tunnel = CloudflareTunnelService();
  }

  Stream<RemoteAccessState> get stateStream => _stateController.stream;
  RemoteAccessState get state => _state;
  RemoteAccessTables get tables => _tables;
  AuthService get auth => _auth;
  ApiService get api => _api;

  Future<void> initialize() async {
    if (_initialized) return;
    await _tables.ensureSchema();
    final secret = await _getOrCreateSecret();
    _auth = AuthService(db: _tables, jwtSecret: secret);
    _api = ApiService(_auth, _tables);
    _initialized = true;
  }

  Future<String> _getOrCreateSecret() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, '.jwt_secret'));
    if (await file.exists()) return (await file.readAsString()).trim();
    final secret = sha256.convert(utf8.encode(
      '${DateTime.now().millisecondsSinceEpoch}-${Platform.localHostname}',
    )).toString();
    await file.writeAsString(secret);
    return secret;
  }

  Future<String> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<bool> start({int port = 8080}) async {
    if (_state.enabled) return true;

    final localIp = await detectLocalIp();
    _updateState(state.copyWith(status: 'Starting...', localIp: localIp, localPort: port));

    try {
      final webDir = await _ensureWebClient();

      final apiRouter = Router()
        ..mount('/api/', _api.router)
        ..get('/ws', webSocketHandler((WebSocketChannel ws) {
          _api.wsClients.add(ws);
          ws.stream.listen((msg) {
            try {
              final data = json.decode(msg as String) as Map<String, dynamic>;
              if (data['type'] == 'ping') {
                ws.sink.add(json.encode({'type': 'pong'}));
              }
            } catch (_) {}
          }, onDone: () => _api.wsClients.remove(ws),
             onError: (_) => _api.wsClients.remove(ws));
        }));

      final static = _staticHandler(webDir);
      final handler = const Pipeline()
          .addMiddleware(_logRequests())
          .addMiddleware(_corsHeaders())
          .addMiddleware(_rateLimiter())
          .addHandler((Request request) async {
        final response = await apiRouter(request);
        if (response.statusCode == 404 && !request.url.path.startsWith('api')) {
          return static(request);
        }
        return response;
      });

      _httpServer = await shelf_io.serve(handler, '0.0.0.0', port, shared: true);
      _updateState(state.copyWith(serverRunning: true, status: 'Server started'));

      final tunnelOk = await _tunnel.start(
        localPort: port,
        onUrl: (url) {
          _updateState(state.copyWith(publicUrl: url, status: 'Tunnel active'));
        },
      );

      _updateState(state.copyWith(
        enabled: true,
        tunnelRunning: tunnelOk,
        status: tunnelOk ? 'Running' : 'Server running (no tunnel)',
      ));

      return true;
    } catch (e) {
      _updateState(state.copyWith(status: 'Error: $e', enabled: false));
      return false;
    }
  }

  Future<void> stop() async {
    await _tunnel.stop();
    await _httpServer?.close(force: true);
    _httpServer = null;
    _api.wsClients.clear();
    await _auth.disconnectAll();
    _updateState(const RemoteAccessState(status: 'Stopped'));
  }

  Future<void> restartTunnel() async {
    await _tunnel.stop();
    final ok = await _tunnel.start(
      localPort: state.localPort,
      onUrl: (url) => _updateState(state.copyWith(publicUrl: url, tunnelRunning: true, status: 'Tunnel active')),
    );
    _updateState(state.copyWith(
      tunnelRunning: ok,
      publicUrl: ok ? _tunnel.publicUrl : null,
      status: ok ? 'Running' : 'Tunnel restart failed',
    ));
  }

  void _updateState(RemoteAccessState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<String> _ensureWebClient() async {
    final dir = await getApplicationSupportDirectory();
    final webDir = Directory(p.join(dir.path, 'web_client'));
    if (!await webDir.exists()) await webDir.create(recursive: true);

    final files = {
      'index.html': _webIndexHtml,
      'style.css': _webStyleCss,
      'app.js': _webAppJs,
      'login.js': _webLoginJs,
    };

    for (final entry in files.entries) {
      final file = File(p.join(webDir.path, entry.key));
      await file.writeAsString(entry.value);
    }

    final assetsDir = Directory(p.join(webDir.path, 'assets'));
    if (!await assetsDir.exists()) await assetsDir.create();
    await File(p.join(assetsDir.path, 'Logo.png')).writeAsBytes(base64.decode(_logoBase64));

    return webDir.path;
  }

  Middleware _logRequests() {
    return (innerHandler) => (Request request) async {
      final sw = Stopwatch()..start();
      final response = await innerHandler(request);
      sw.stop();
      print('[${DateTime.now().toIso8601String()}] ${request.method} ${request.url} -> ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
      return response;
    };
  }

  Middleware _corsHeaders() {
    return (innerHandler) => (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'access-control-allow-headers': 'Content-Type, Authorization',
          'access-control-max-age': '86400',
        });
      }
      final response = await innerHandler(request);
      return response.change(headers: {'access-control-allow-origin': '*'});
    };
  }

  Middleware _rateLimiter() {
    final requests = <String, List<int>>{};
    return (innerHandler) => (Request request) async {
      final ip = request.headers['x-forwarded-for']?.split(',').first.trim() ?? 'local';
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = requests.putIfAbsent(ip, () => []);
      history.add(now);
      history.removeWhere((t) => t < now - 1000);
      if (history.length > 30) {
        return Response(429, body: json.encode({'error': 'Rate limit exceeded'}));
      }
      return innerHandler(request);
    };
  }

  Handler _staticHandler(String root) {
    final handler = createStaticHandler(root, defaultDocument: 'index.html');
    return (Request request) async {
      final response = await handler(request);
      if (response.statusCode == 404) {
        return Response.found('/index.html');
      }
      return response;
    };
  }

  void dispose() {
    _stateController.close();
  }
}

final _webIndexHtml = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>CashManager Inventory</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div id="app">
  <div id="login-screen" class="screen active">
    <div class="login-container">
    <img class="logo-icon" src="assets/Logo.png" alt="CashManager Logo">
      <h1 class="login-title">CashManager</h1>
      <p class="login-subtitle">Sign in to continue</p>
      <form id="login-form" autocomplete="off">
        <div class="form-group">
          <label for="username">Username</label>
          <input type="text" id="username" placeholder="Enter your username" required autocomplete="username">
        </div>
        <div class="form-group">
          <label for="password">Password</label>
          <input type="password" id="password" placeholder="Enter your password" required autocomplete="current-password">
        </div>
        <div class="form-group checkbox-group">
          <label class="checkbox-label"><input type="checkbox" id="remember"> Remember Me</label>
        </div>
        <div id="login-error" class="error-msg"></div>
        <button type="submit" id="login-btn" class="btn btn-primary btn-full">Sign In</button>
      </form>
    </div>
  </div>
  <div id="pos-screen" class="screen">
    <header class="pos-header">
      <button id="menu-toggle" class="menu-btn" aria-label="Toggle menu">☰</button>
      <h2 class="header-title">CashManager</h2>
      <div class="header-center" id="header-title">Dashboard</div>
      <div class="header-right">
        <span id="connection-status" class="badge badge-connected">● Connected</span>
        <span id="user-badge" class="user-badge"></span>
        <button id="logout-btn" class="btn btn-outline btn-sm">Logout</button>
      </div>
    </header>
    <div class="pos-body">
      <div id="sidebar-overlay" class="sidebar-overlay"></div>
      <nav id="sidebar" class="sidebar">
        <button class="nav-item active" data-view="dashboard"><span class="nav-icon">📊</span><span class="nav-label">Dashboard</span></button>
        <button class="nav-item" data-view="products"><span class="nav-icon">📦</span><span class="nav-label">Products</span></button>
        <button class="nav-item" data-view="categories"><span class="nav-icon">🏷️</span><span class="nav-label">Categories</span></button>
        <button class="nav-item" data-view="inventory"><span class="nav-icon">📋</span><span class="nav-label">Inventory</span></button>
        <button class="nav-item" data-view="sales"><span class="nav-icon">💰</span><span class="nav-label">Sales</span></button>
        <button class="nav-item" data-view="sessions" id="nav-sessions" style="display:none"><span class="nav-icon">🔌</span><span class="nav-label">Sessions</span></button>
      </nav>
      <main id="main-content" class="main-content"><div class="loading">Loading...</div></main>
    </div>
    <nav class="bottom-nav">
      <div class="bottom-nav-inner">
        <button class="bottom-nav-item active" data-bn-view="dashboard"><span class="bn-icon">📊</span>Home</button>
        <button class="bottom-nav-item" data-bn-view="products"><span class="bn-icon">📦</span>Products</button>
        <button class="bottom-nav-item" data-bn-view="categories"><span class="bn-icon">🏷️</span>Categories</button>
        <button class="bottom-nav-item" data-bn-view="inventory"><span class="bn-icon">📋</span>Stock</button>
        <button class="bottom-nav-item" data-bn-view="sales"><span class="bn-icon">💰</span>Sales</button>
      </div>
    </nav>
  </div>
</div>
<div id="modal-overlay" class="modal-overlay">
  <div class="modal">
    <div class="modal-header">
      <h3>Sale Details</h3>
      <button class="modal-close" id="modal-close">&times;</button>
    </div>
    <div class="modal-body" id="modal-body"></div>
  </div>
</div>
<script src="login.js"></script>
<script src="app.js"></script>
</body>
</html>''';

final _webStyleCss = r'''*{margin:0;padding:0;box-sizing:border-box}:root{--primary:#FF7A00;--primary-hover:#FF9433;--primary-light:#FFF3E6;--primary-dark:#E06E00;--bg:#F5F3F2;--surface:#fff;--text:#1A2B49;--text-secondary:#6B7280;--border:#E5E7EB;--success:#10B981;--success-bg:#d1fae5;--success-text:#065f46;--danger:#E74C3C;--danger-bg:#fef2f2;--danger-text:#991b1b;--warning:#f59e0b;--warning-bg:#fffbeb;--warning-text:#92400e;--info:#3b82f6;--info-bg:#eff6ff;--info-text:#1e40af;--radius:12px;--radius-sm:8px;--radius-xs:6px;--shadow:0 1px 3px rgba(0,0,0,.08);--shadow-md:0 4px 12px rgba(0,0,0,.1);--shadow-lg:0 8px 32px rgba(0,0,0,.15);--transition:all .2s ease;--sidebar-w:220px;--header-h:56px;--bottom-nav-h:60px;--sidebar-bg:#1A2B49;--sidebar-text:#CBD5E1;--sidebar-text-active:#fff}
html,body{height:100%;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,sans-serif;background:var(--bg);color:var(--text);font-size:14px;line-height:1.5;overflow:hidden}.screen{display:none;height:100%}.screen.active{display:flex}
#login-screen{align-items:center;justify-content:center;background:linear-gradient(135deg,#FF7A00 0%,#E06E00 100%);padding:16px}
.login-container{background:var(--surface);border-radius:var(--radius);padding:40px 32px;width:100%;max-width:400px;box-shadow:var(--shadow-lg)}.login-logo{margin-bottom:16px}
.logo-icon{width:56px;height:56px;border-radius:14px;display:block;margin:0 auto}
.login-title{text-align:center;font-size:22px;margin-bottom:4px}.login-subtitle{text-align:center;color:var(--text-secondary);margin-bottom:24px;font-size:14px}
.form-group{margin-bottom:16px}.form-group label{display:block;font-size:12px;font-weight:600;color:var(--text-secondary);margin-bottom:4px;text-transform:uppercase;letter-spacing:.5px}
.form-group input[type="text"],.form-group input[type="password"],.form-group input[type="number"],.form-group input[type="email"],.form-group input[type="search"],.form-group select{width:100%;padding:10px 12px;border:1.5px solid var(--border);border-radius:var(--radius-sm);font-size:14px;transition:var(--transition);background:var(--surface);color:var(--text)}
.form-group input:focus,.form-group select:focus{border-color:var(--primary);outline:none;box-shadow:0 0 0 3px var(--primary-light)}input.input-error{border-color:var(--danger)}.checkbox-group{margin-bottom:8px}
.checkbox-label{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--text-secondary);cursor:pointer;text-transform:none!important;letter-spacing:0!important;font-weight:400!important}
.error-msg{color:var(--danger);font-size:12px;min-height:18px;margin-bottom:8px}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:6px;padding:10px 20px;border:none;border-radius:var(--radius-sm);font-size:14px;font-weight:600;cursor:pointer;transition:var(--transition);white-space:nowrap;user-select:none}.btn:active{transform:scale(.97)}
.btn-primary{background:var(--primary);color:#fff}.btn-primary:hover{background:var(--primary-hover)}.btn-primary:active{background:var(--primary-dark)}
.btn-outline{background:transparent;border:1.5px solid var(--border);color:var(--text)}.btn-outline:hover{border-color:var(--primary);color:var(--primary)}
.btn-danger{background:var(--danger);color:#fff}.btn-danger:hover{background:#dc2626}.btn-success{background:var(--success);color:#fff}.btn-success:hover{background:#16a34a}.btn-warning{background:var(--warning);color:#fff}.btn-warning:hover{background:#d97706}
.btn-sm{padding:6px 12px;font-size:12px}.btn-xs{padding:3px 8px;font-size:11px;border-radius:4px}.btn-full{width:100%;padding:12px}.btn-icon{background:none;border:none;font-size:20px;cursor:pointer;padding:6px;color:var(--text-secondary);border-radius:6px;line-height:1}.btn-icon:hover{background:var(--bg);color:var(--text)}.btn-icon:active{transform:scale(.92)}.btn-group{display:flex;gap:6px;flex-wrap:wrap}
#pos-screen{flex-direction:column}.pos-header{display:flex;align-items:center;gap:8px;padding:0 16px;background:var(--surface);border-bottom:1px solid var(--border);box-shadow:var(--shadow);height:var(--header-h);flex-shrink:0;z-index:100;position:relative}
.menu-btn{display:none;background:none;border:none;font-size:22px;cursor:pointer;padding:4px 8px;color:var(--text-secondary);border-radius:6px;line-height:1}.menu-btn:hover{background:var(--bg);color:var(--text)}
.header-title{font-size:16px;font-weight:700;white-space:nowrap;color:var(--primary)}.header-center{flex:1;text-align:center;font-size:15px;font-weight:600;color:var(--text-secondary);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:0 8px}
.header-right{display:flex;align-items:center;gap:8px;margin-left:auto;flex-shrink:0}.badge{display:inline-flex;align-items:center;gap:4px;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:600}
.badge-connected{background:#d1fae5;color:#065f46}.badge-disconnected{background:var(--danger-bg);color:var(--danger-text)}
.user-badge{display:inline-flex;align-items:center;gap:4px;padding:3px 10px;border-radius:20px;background:var(--primary-light);color:var(--primary);font-size:12px;font-weight:600;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.pos-body{display:flex;flex:1;overflow:hidden;position:relative}.sidebar-overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:199;opacity:0;transition:opacity .3s ease}.sidebar-overlay.open{display:block;opacity:1}
.sidebar{width:var(--sidebar-w);flex-shrink:0;background:var(--sidebar-bg);border-right:none;padding:8px 0;overflow-y:auto;display:flex;flex-direction:column;z-index:200}
.nav-item{display:flex;align-items:center;gap:10px;width:100%;padding:10px 16px;border:none;background:none;font-size:13px;font-weight:500;color:var(--sidebar-text);cursor:pointer;transition:var(--transition);text-align:left;border-left:3px solid transparent}
.nav-item:hover{background:rgba(255,255,255,.08);color:var(--sidebar-text-active)}.nav-item.active{background:rgba(255,122,0,.15);color:var(--sidebar-text-active);font-weight:600;border-left-color:var(--primary)}.nav-icon{font-size:18px;width:24px;text-align:center;flex-shrink:0}
.main-content{flex:1;overflow-y:auto;padding:20px;background:var(--bg);-webkit-overflow-scrolling:touch}.loading{text-align:center;padding:60px 20px;color:var(--text-secondary);font-size:15px}
.card{background:var(--surface);border-radius:var(--radius);padding:20px;box-shadow:var(--shadow);margin-bottom:16px}.card-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;flex-wrap:wrap;gap:8px}.card-header h3{font-size:16px;font-weight:700}.card-actions{display:flex;gap:8px;flex-wrap:wrap}
.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px;margin-bottom:20px}.stat-card{background:var(--surface);border-radius:var(--radius);padding:20px;box-shadow:var(--shadow);text-align:center;transition:var(--transition)}.stat-card:hover{box-shadow:var(--shadow-md);transform:translateY(-1px)}.stat-card .stat-value{font-size:28px;font-weight:700;color:var(--primary)}.stat-card .stat-label{font-size:11px;color:var(--text-secondary);margin-top:4px;text-transform:uppercase;letter-spacing:.5px;font-weight:600}
.table-container{overflow-x:auto;max-height:calc(100vh - 56px - 120px);-webkit-overflow-scrolling:touch}.table-container table{min-width:500px}
table{width:100%;border-collapse:collapse}table th,table td{padding:10px 12px;text-align:left;border-bottom:1px solid var(--border);font-size:13px}table th{font-size:11px;font-weight:600;color:var(--text-secondary);text-transform:uppercase;letter-spacing:.5px;background:var(--bg);position:sticky;top:0;z-index:1}table tr:hover td{background:var(--primary-light)}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:16px;align-items:center}.search-input{padding:8px 12px;border:1.5px solid var(--border);border-radius:var(--radius-sm);font-size:13px;flex:1;min-width:160px;max-width:400px}.search-input:focus{border-color:var(--primary);outline:none;box-shadow:0 0 0 3px var(--primary-light)}.filter-select{padding:8px 12px;border:1.5px solid var(--border);border-radius:var(--radius-sm);font-size:13px;background:var(--surface);color:var(--text);cursor:pointer}
.modal-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.45);z-index:1000;display:none;align-items:center;justify-content:center;padding:20px}.modal-overlay.active{display:flex}
.modal{background:var(--surface);border-radius:var(--radius);max-width:600px;width:100%;max-height:85vh;overflow-y:auto;box-shadow:var(--shadow-lg)}.modal-header{display:flex;align-items:center;justify-content:space-between;padding:16px 20px;border-bottom:1px solid var(--border);flex-shrink:0}.modal-header h3{font-size:16px;margin:0;font-weight:700}.modal-close{background:none;border:none;font-size:24px;cursor:pointer;color:var(--text-secondary);padding:0;line-height:1;width:28px;height:28px;display:flex;align-items:center;justify-content:center;border-radius:6px;transition:var(--transition)}.modal-close:hover{background:var(--bg);color:var(--text)}.modal-body{padding:20px}.modal-footer{display:flex;gap:8px;justify-content:flex-end;padding:12px 20px;border-top:1px solid var(--border);flex-wrap:wrap}
.badge-pill{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:600}.badge-success{background:var(--success-bg);color:var(--success-text)}.badge-danger{background:var(--danger-bg);color:var(--danger-text)}.badge-warning{background:var(--warning-bg);color:var(--warning-text)}.badge-info{background:var(--info-bg);color:var(--info-text)}
.empty-state{text-align:center;padding:40px 20px;color:var(--text-secondary)}.empty-state .empty-icon{font-size:48px;margin-bottom:12px}.empty-state p{font-size:14px}
.inline-form{display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap}.inline-form input,.inline-form select{flex:1;min-width:100px;padding:8px 12px;border:1.5px solid var(--border);border-radius:var(--radius-sm);font-size:13px}.inline-form input:focus,.inline-form select:focus{border-color:var(--primary);outline:none}
.ml-auto{margin-left:auto}.text-right{text-align:right}.text-center{text-align:center}.w-full{width:100%}.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:12px}.grid-3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px}
#pos-view{display:flex;gap:16px;height:100%;overflow:hidden}.pos-products{flex:1;display:flex;flex-direction:column;overflow:hidden;min-width:0}.pos-cart{width:340px;flex-shrink:0;display:flex;flex-direction:column;background:var(--surface);border-radius:var(--radius);box-shadow:var(--shadow);overflow:hidden}
.pos-toolbar{display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap}.pos-toolbar .search-input{flex:1;min-width:120px}
.category-pills{display:flex;gap:6px;margin-bottom:12px;overflow-x:auto;padding-bottom:4px;-webkit-overflow-scrolling:touch;flex-shrink:0}
.sale-meta{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:16px;font-size:13px}.sale-meta strong{color:var(--text-secondary)}
.bottom-nav{display:none;position:fixed;bottom:0;left:0;right:0;height:60px;background:var(--sidebar-bg);border-top:1px solid rgba(255,255,255,.1);z-index:99;padding:0 4px;box-shadow:0 -2px 8px rgba(0,0,0,.2)}
.bottom-nav-inner{display:flex;overflow-x:auto;height:100%}.bottom-nav-item{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;padding:4px 8px;border:none;background:none;font-size:10px;color:var(--sidebar-text);cursor:pointer;white-space:nowrap;min-width:60px;transition:var(--transition);flex-shrink:0}.bottom-nav-item .bn-icon{font-size:18px}.bottom-nav-item.active{color:var(--primary);font-weight:600}
@media(max-width:900px){
.menu-btn{display:inline-flex}.sidebar{position:fixed;left:-260px;top:56px;bottom:60px;width:240px;z-index:200;transition:left .3s ease;box-shadow:var(--shadow-lg);border-right:none}.sidebar.open{left:0}.sidebar-overlay{display:block;pointer-events:none}.sidebar-overlay.open{pointer-events:auto}.main-content{padding:16px}.stats-grid{grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.bottom-nav{display:block}.pos-body{margin-bottom:60px}.grid-2,.grid-3{grid-template-columns:1fr}
}
@media(max-width:768px){
.header-center{display:none}.user-badge{max-width:80px}.main-content{padding:12px}.stats-grid{grid-template-columns:1fr 1fr;gap:10px}.stat-card .stat-value{font-size:24px}.stat-card{padding:16px}.login-container{padding:28px 20px}table th,table td{padding:8px 6px;font-size:12px}
}
@media(max-width:480px){
.card{padding:14px}.stats-grid{grid-template-columns:1fr 1fr;gap:8px}.stat-card .stat-value{font-size:20px}.toolbar{flex-direction:column}.toolbar .search-input{max-width:none;width:100%}.btn-sm{padding:5px 10px;font-size:11px}
}
''';

final _webLoginJs = r'''document.getElementById('login-form').addEventListener('submit',async function(e){
e.preventDefault()
const u=document.getElementById('username').value
const p=document.getElementById('password').value
const r=document.getElementById('remember').checked
const btn=document.getElementById('login-btn')
const err=document.getElementById('login-error')
btn.disabled=true;btn.textContent='Signing in...';err.textContent=''
try{const res=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,password:p,device:navigator.userAgent,browser:navigator.userAgent})})
const d=await res.json()
if(d.success){localStorage.setItem('token',d.token)
if(r)localStorage.setItem('refreshToken',d.refreshToken)
localStorage.setItem('user',JSON.stringify(d.user))
window.app.init(d.user)}else{err.textContent=d.error||'Login failed'}}
catch(ex){err.textContent='Connection error'}
finally{btn.disabled=false;btn.textContent='Sign In'}});''';

final _webAppJs = r'''window.app={
token:localStorage.getItem('token'),user:null,currentView:'dashboard',ws:null,
init(u){this.user=u||JSON.parse(localStorage.getItem('user')||'{}')
if(!this.user||!this.user.id)return this.showLogin()
document.getElementById('login-screen').classList.remove('active')
document.getElementById('pos-screen').classList.add('active')
document.getElementById('user-badge').textContent=this.user.username
if(this.user.role==='administrator'||this.user.role==='manager')document.getElementById('nav-sessions').style.display=''
this.connectWebSocket();this.navigate('dashboard')},
showLogin(){localStorage.clear();document.getElementById('pos-screen').classList.remove('active');document.getElementById('login-screen').classList.add('active')},
connectWebSocket(){const p=location.protocol==='https:'?'wss:':'ws:';const u=p+'//'+location.host+'/ws'
try{this.ws=new WebSocket(u)
this.ws.onopen=()=>{document.getElementById('connection-status').textContent='Connected';document.getElementById('connection-status').className='badge badge-connected'}
this.ws.onclose=()=>{document.getElementById('connection-status').textContent='Disconnected';document.getElementById('connection-status').className='badge badge-disconnected';setTimeout(()=>this.connectWebSocket(),3000)}
this.ws.onmessage=(e)=>{try{const d=JSON.parse(e.data);if(d.type&&d.type!=='pong'){if(this.currentView==='dashboard')this.loadDashboard();if(this.currentView==='products')this.loadProducts();if(this.currentView==='inventory')this.loadInventory()}}catch(_){}}
this.ws.onerror=()=>{}}catch(_){setTimeout(()=>this.connectWebSocket(),5000)}},
toggleSidebar(){document.getElementById('sidebar').classList.toggle('open');document.getElementById('sidebar-overlay').classList.toggle('open')},
closeSidebar(){document.getElementById('sidebar').classList.remove('open');document.getElementById('sidebar-overlay').classList.remove('open')},
navigate(v){this.currentView=v;this.closeSidebar()
document.querySelectorAll('.nav-item,.bottom-nav-item').forEach(n=>n.classList.remove('active'))
document.querySelector('[data-view="'+v+'"]')?.classList.add('active')
document.querySelector('[data-bn-view="'+v+'"]')?.classList.add('active')
const titles={dashboard:'Dashboard',products:'Products',categories:'Categories',inventory:'Inventory',sales:'Sales',sessions:'Active Sessions'}
document.getElementById('header-title').textContent=titles[v]||v
const fns={dashboard:()=>this.loadDashboard(),products:()=>this.loadProducts(),categories:()=>this.loadCategories(),inventory:()=>this.loadInventory(),sales:()=>this.loadSales(),sessions:()=>this.loadSessions()}
if(fns[v])fns[v]()},
async loadDashboard(){const m=document.getElementById('main-content')
try{const r=await fetch('/api/dashboard',{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.stats){m.innerHTML='<div class="loading" style="color:var(--danger)">Auth error: '+(d.error||'unknown')+'<br><br><button class="btn btn-primary" onclick="window.app.showLogin()">Back to Login</button></div>';return}
const s=d.stats
m.innerHTML='<div class="stats-grid"><div class="stat-card"><div class="stat-value">'+this.n0(s.products)+'</div><div class="stat-label">Products</div></div><div class="stat-card"><div class="stat-value">'+this.n0(s.categories)+'</div><div class="stat-label">Categories</div></div><div class="stat-card"><div class="stat-value">'+this.n0(s.totalOrders)+'</div><div class="stat-label">Total Orders</div></div><div class="stat-card"><div class="stat-value" style="color:var(--success)">'+this.fmt(s.todaySales)+'</div><div class="stat-label">Today\'s Revenue</div></div></div>'}
catch(_){m.innerHTML='<div class="loading">Failed to load dashboard</div>'}},
n0(v){return v??0},
fmt(v){if(v==null)return'0';return Number(v).toLocaleString()+' DH'},
async loadProducts(){const m=document.getElementById('main-content');m.innerHTML='<div class="loading">Loading...</div>'
try{const r=await fetch('/api/products',{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.products)return this.showLogin()
let h='<div class="card"><div class="card-header"><h3>Products</h3></div><div class="toolbar"><input type="search" class="search-input" id="product-search" placeholder="Search products..." onkeyup="window.app.searchProducts(this.value)"></div><div class="table-container"><table><thead><tr><th>Name</th><th>Price</th><th>Stock</th><th>Category</th><th>Barcode</th></tr></thead><tbody>'
for(const p of d.products){h+='<tr><td><strong>'+(p.name||'--')+'</strong></td><td>'+this.fmt(p.selling_price)+'</td><td><span class="badge-pill '+(p.quantity>0?'badge-success':'badge-danger')+'">'+(p.quantity||0)+'</span></td><td>'+(p.category_name||'--')+'</td><td>'+(p.barcode||'--')+'</td></tr>'}
h+='</tbody></table></div></div>';m.innerHTML=h}
catch(_){m.innerHTML='<div class="loading">Failed to load products</div>'}},
async searchProducts(q){if(!q)return this.loadProducts()
try{const r=await fetch('/api/products/search?q='+encodeURIComponent(q),{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json();const tb=document.querySelector('#main-content tbody')
if(!tb||!d.products)return;tb.innerHTML=''
for(const p of d.products){tb.innerHTML+='<tr><td><strong>'+(p.name||'--')+'</strong></td><td>'+this.fmt(p.selling_price)+'</td><td><span class="badge-pill '+(p.quantity>0?'badge-success':'badge-danger')+'">'+(p.quantity||0)+'</span></td><td>'+(p.category_name||'--')+'</td><td>'+(p.barcode||'--')+'</td></tr>'}}
catch(_){}},
async loadCategories(){const m=document.getElementById('main-content');m.innerHTML='<div class="loading">Loading...</div>'
try{const r=await fetch('/api/categories',{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.categories)return this.showLogin()
let h='<div class="card"><div class="card-header"><h3>Categories</h3></div><div class="table-container"><table><thead><tr><th>Name</th><th>Parent</th></tr></thead><tbody>'
for(const c of d.categories){h+='<tr><td><strong>'+(c.name||'--')+'</strong></td><td>'+(c.parent_id||'--')+'</td></tr>'}
h+='</tbody></table></div></div>';m.innerHTML=h}
catch(_){m.innerHTML='<div class="loading">Failed to load categories</div>'}},
async loadInventory(){const m=document.getElementById('main-content');m.innerHTML='<div class="loading">Loading...</div>'
try{const r=await fetch('/api/inventory',{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.inventory)return this.showLogin()
let h='<div class="card"><div class="card-header"><h3>Inventory</h3></div><div class="table-container"><table><thead><tr><th>Product</th><th>Stock</th><th>Price</th></tr></thead><tbody>'
for(const i of d.inventory){h+='<tr><td>'+(i.name||'--')+'</td><td><span class="badge-pill '+(i.quantity>0?(i.quantity<5?'badge-warning':'badge-success'):'badge-danger')+'">'+(i.quantity||0)+'</span></td><td>'+this.fmt(i.selling_price)+'</td></tr>'}
h+='</tbody></table></div></div>';m.innerHTML=h}
catch(_){m.innerHTML='<div class="loading">Failed to load inventory</div>'}},
async loadSales(){const m=document.getElementById('main-content');m.innerHTML='<div class="loading">Loading...</div>'
try{const r=await fetch('/api/sales',{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.sales)return this.showLogin()
let h='<div class="card"><div class="card-header"><h3>Sales</h3></div><div class="table-container"><table><thead><tr><th>Order</th><th>Total</th><th>Method</th><th>Items</th><th>Date</th></tr></thead><tbody>'
for(const s of d.sales){h+='<tr class="clickable" onclick="window.app.showSaleDetail(\''+s.id+'\')"><td><strong>#'+(s.invoice_number||s.id||'--')+'</strong></td><td>'+this.fmt(s.total)+'</td><td><span class="badge-pill badge-info">'+(s.payment_method||'--')+'</span></td><td>'+(s.items_count||'--')+'</td><td>'+(s.created_at?new Date(s.created_at).toLocaleString():'--')+'</td></tr>'}
h+='</tbody></table></div></div>';m.innerHTML=h}
catch(_){m.innerHTML='<div class="loading">Failed to load sales</div>'}},
async showSaleDetail(id){try{const r=await fetch('/api/sales/'+id,{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.sale)return
const s=d.sale;let items='';let n=0
for(const i of s.items||[]){n++;items+='<tr><td>'+(i.product_name||i.product_id||'--')+'</td><td>'+i.quantity+'</td><td>'+this.fmt(i.price)+'</td><td>'+this.fmt((i.quantity||0)*(i.price||0))+'</td></tr>'}
document.getElementById('modal-overlay').classList.add('active')
document.getElementById('modal-body').innerHTML='<div class="sale-meta"><div><strong>Invoice:</strong><br>#'+(s.invoice_number||s.id||'--')+'</div><div><strong>Date:</strong><br>'+(s.created_at?new Date(s.created_at).toLocaleString():'--')+'</div><div><strong>Total:</strong><br><span style="font-size:20px;font-weight:700;color:var(--primary)">'+this.fmt(s.total)+'</span></div><div><strong>Payment:</strong><br><span class="badge-pill badge-info">'+(s.payment_method||'--')+'</span></div></div><table><thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>Total</th></tr></thead><tbody>'+items+'</tbody></table>'}
catch(_){}},
closeModal(){document.getElementById('modal-overlay').classList.remove('active')},
async loadSessions(){const m=document.getElementById('main-content');m.innerHTML='<div class="loading">Loading...</div>'
try{const r=await fetch('/api/sessions',{headers:{Authorization:'Bearer '+localStorage.getItem('token')}})
const d=await r.json()
if(!d.sessions)return this.showLogin()
let h='<div class="card"><div class="card-header"><h3>Active Sessions</h3></div><div class="table-container"><table><thead><tr><th>User</th><th>Role</th><th>Device</th><th>IP</th><th>Duration</th><th>Action</th></tr></thead><tbody>'
for(const s of d.sessions){h+='<tr><td><strong>'+(s.username||'--')+'</strong></td><td><span class="badge-pill badge-info">'+(s.role||'--')+'</span></td><td>'+(s.browser||s.device||'--')+'</td><td>'+(s.ipAddress||'--')+'</td><td>'+(s.duration||0)+'s</td><td><button class="btn btn-sm btn-outline" onclick="window.app.disconnectSession(\''+s.id+'\')">Disconnect</button></td></tr>'}
h+='</tbody></table></div></div>';m.innerHTML=h}
catch(_){m.innerHTML='<div class="loading">Failed to load sessions</div>'}},
async disconnectSession(id){if(!confirm('Disconnect session?'))return
try{await fetch('/api/sessions/'+id+'/disconnect',{method:'POST',headers:{Authorization:'Bearer '+localStorage.getItem('token')}});this.loadSessions()}catch(_){}},
dispose(){if(this.ws){this.ws.close();this.ws=null}}
};

// Event listeners
document.getElementById('logout-btn').addEventListener('click',()=>{localStorage.clear();window.app.showLogin()})
document.getElementById('menu-toggle').addEventListener('click',()=>{window.app.toggleSidebar()})
document.getElementById('sidebar-overlay').addEventListener('click',()=>{window.app.closeSidebar()})
document.querySelectorAll('[data-view]').forEach(el=>{el.addEventListener('click',()=>{window.app.navigate(el.dataset.view)})})
document.querySelectorAll('[data-bn-view]').forEach(el=>{el.addEventListener('click',()=>{window.app.navigate(el.dataset.bnView)})})
document.getElementById('modal-close').addEventListener('click',()=>{window.app.closeModal()})
document.getElementById('modal-overlay').addEventListener('click',(e)=>{if(e.target===e.currentTarget)window.app.closeModal()})

// Initialize
const token=localStorage.getItem('token')
if(token)window.app.init()''';

const _logoBase64 = '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';


