import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:restropos/core/remote_access/database/remote_access_db.dart';
import 'package:restropos/core/remote_access/models/remote_access_models.dart';

class AuthService {
  final RemoteAccessTables _db;
  final String _jwtSecret;
  final Duration _accessTokenDuration;
  final Duration _refreshTokenDuration;
  final Map<String, DateTime> _refreshTokens = {};
  final Map<String, int> _loginAttempts = {};
  final Set<String> _blacklistedTokens = {};

  AuthService({
    required RemoteAccessTables db,
    required String jwtSecret,
    Duration? accessTokenDuration,
    Duration? refreshTokenDuration,
  })  : _db = db,
        _jwtSecret = jwtSecret,
        _accessTokenDuration = accessTokenDuration ?? const Duration(hours: 2),
        _refreshTokenDuration = refreshTokenDuration ?? const Duration(days: 7);

  Future<AuthResult> login(
    String username,
    String password, {
    String device = '',
    String browser = '',
    String ipAddress = '',
    String? country,
  }) async {
    final key = ipAddress.isNotEmpty ? ipAddress : 'global';
    final attempts = _loginAttempts[key] ?? 0;
    if (attempts >= 5) {
      return const AuthResult(success: false, error: 'Too many attempts. Try again later.');
    }

    final user = await _db.authenticate(username, password);
    if (user == null) {
      _loginAttempts[key] = attempts + 1;
      Future.delayed(const Duration(minutes: 15), () {
        final cur = _loginAttempts[key] ?? 0;
        if (cur > 0) _loginAttempts[key] = cur - 1;
      });
      return const AuthResult(success: false, error: 'Invalid username or password');
    }

    _loginAttempts.remove(key);
    final sessionId = await _db.createSession(
      user.id, user.username, user.role.name,
      device: device, browser: browser, ipAddress: ipAddress, country: country,
    );

    final accessToken = _generateJwt(user.id, sessionId, user.role.name, _accessTokenDuration);
    final refreshToken = _generateRefreshToken(sessionId);

    await _db.logAudit(user.id, user.username, 'LOGIN', null, ipAddress);
    return AuthResult(success: true, token: accessToken, refreshToken: refreshToken, user: user);
  }

  Future<AuthResult> refreshToken(String refreshToken) async {
    MapEntry<String, DateTime>? found;
    for (final e in _refreshTokens.entries) {
      if (e.key == refreshToken && e.value.isAfter(DateTime.now())) {
        found = e;
        break;
      }
    }
    if (found == null) return const AuthResult(success: false, error: 'Invalid or expired refresh token');

    _refreshTokens.remove(refreshToken);
    final parts = refreshToken.split('.');
    final sessionId = parts.length > 1 ? parts.last : '';

    try {
      final sessions = await _db.getActiveSessions();
      final session = sessions.where((s) => s.id == sessionId).firstOrNull;
      if (session == null) return const AuthResult(success: false, error: 'Session expired');

      final user = await _db.getUserById(session.userId);
      if (user == null || !user.isActive) return const AuthResult(success: false, error: 'User inactive');

      final token = _generateJwt(user.id, session.id, user.role.name, _accessTokenDuration);
      final newRt = _generateRefreshToken(session.id);
      await _db.touchSession(session.id);
      return AuthResult(success: true, token: token, refreshToken: newRt, user: user);
    } catch (_) {
      return const AuthResult(success: false, error: 'Session error');
    }
  }

  Future<RemoteUser?> validateToken(String token) async {
    if (_blacklistedTokens.contains(token)) return null;
    try {
      final payload = _verifyJwt(token);
      if (payload == null) return null;

      final userId = payload['uid'] as String?;
      final sessionId = payload['sid'] as String?;
      final exp = (payload['exp'] as num?)?.toInt();
      if (userId == null || sessionId == null || exp == null) return null;

      if (DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) return null;

      await _db.touchSession(sessionId);
      return await _db.getUserById(userId);
    } catch (_) {
      return null;
    }
  }

  bool hasPermission(RemoteUser? user, UserRole requiredRole) {
    if (user == null) return false;
    const hierarchy = {UserRole.viewer: 0, UserRole.cashier: 1, UserRole.manager: 2, UserRole.administrator: 3};
    return (hierarchy[user.role] ?? 0) >= (hierarchy[requiredRole] ?? 0);
  }

  Future<void> logout(String token, String? refreshToken) async {
    if (token.isNotEmpty) _blacklistedTokens.add(token);
    if (refreshToken != null) _refreshTokens.remove(refreshToken);
  }

  Future<void> disconnectSession(String sessionId) async {
    await _db.endSession(sessionId);
  }

  Future<void> disconnectAll() async {
    await _db.endAllSessions();
    _refreshTokens.clear();
  }

  String _generateJwt(String userId, String sessionId, String role, Duration duration) {
    final header = _b64url(json.encode({'alg': 'HS256', 'typ': 'JWT'}));
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = _b64url(json.encode({
      'uid': userId, 'sid': sessionId, 'role': role, 'iat': now,
      'exp': now + duration.inSeconds,
    }));
    final sig = _hmac('$header.$payload', _jwtSecret);
    return '$header.$payload.$sig';
  }

  Map<String, dynamic>? _verifyJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final expectedSig = _hmac('${parts[0]}.${parts[1]}', _jwtSecret);
    if (!_secureEquals(parts[2], expectedSig)) return null;
    try {
      return json.decode(utf8.decode(_b64dec(parts[1]))) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _hmac(String data, String secret) {
    final h = Hmac(sha256, utf8.encode(secret));
    return _b64url(h.convert(utf8.encode(data)).bytes);
  }

  String _generateRefreshToken(String sessionId) {
    final token = '${_randomString(48)}.$sessionId';
    _refreshTokens[token] = DateTime.now().add(_refreshTokenDuration);
    return token;
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _b64url(dynamic data) =>
      base64Url.encode((data is List<int> ? data : utf8.encode(data.toString()))).replaceAll('=', '');
  List<int> _b64dec(String data) {
    final rem = data.length % 4;
    if (rem == 2) data = '${data}==';
    if (rem == 3) data = '${data}=';
    return base64Url.decode(data);
  }
  bool _secureEquals(String a, String b) {
    if (a.length != b.length) return false;
    int r = 0;
    for (int i = 0; i < a.length; i++) r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    return r == 0;
  }
}
