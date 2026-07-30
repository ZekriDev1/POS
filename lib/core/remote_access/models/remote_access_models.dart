enum UserRole { administrator, manager, cashier, viewer }

class RemoteUser {
  final String id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  RemoteUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class UserSession {
  final String id;
  final String userId;
  final String username;
  final UserRole role;
  final String device;
  final String browser;
  final String ipAddress;
  final String? country;
  final DateTime loginTime;
  final DateTime lastActivity;
  final bool isActive;

  UserSession({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    required this.device,
    required this.browser,
    required this.ipAddress,
    this.country,
    DateTime? loginTime,
    DateTime? lastActivity,
    this.isActive = true,
  })  : loginTime = loginTime ?? DateTime.now(),
        lastActivity = lastActivity ?? DateTime.now();

  Duration get duration => DateTime.now().difference(loginTime);
}

class AuditLog {
  final int id;
  final String userId;
  final String username;
  final String action;
  final String? details;
  final String ipAddress;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    required this.username,
    required this.action,
    this.details,
    required this.ipAddress,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class RemoteAccessState {
  final bool enabled;
  final bool tunnelRunning;
  final bool serverRunning;
  final String? localIp;
  final int localPort;
  final String? publicUrl;
  final List<UserSession> connectedSessions;
  final int activeUsers;
  final DateTime? lastConnection;
  final String status;

  const RemoteAccessState({
    this.enabled = false,
    this.tunnelRunning = false,
    this.serverRunning = false,
    this.localIp,
    this.localPort = 8080,
    this.publicUrl,
    this.connectedSessions = const [],
    this.activeUsers = 0,
    this.lastConnection,
    this.status = 'Stopped',
  });

  RemoteAccessState copyWith({
    bool? enabled,
    bool? tunnelRunning,
    bool? serverRunning,
    String? localIp,
    int? localPort,
    String? publicUrl,
    List<UserSession>? connectedSessions,
    int? activeUsers,
    DateTime? lastConnection,
    String? status,
  }) => RemoteAccessState(
    enabled: enabled ?? this.enabled,
    tunnelRunning: tunnelRunning ?? this.tunnelRunning,
    serverRunning: serverRunning ?? this.serverRunning,
    localIp: localIp ?? this.localIp,
    localPort: localPort ?? this.localPort,
    publicUrl: publicUrl ?? this.publicUrl,
    connectedSessions: connectedSessions ?? this.connectedSessions,
    activeUsers: activeUsers ?? this.activeUsers,
    lastConnection: lastConnection ?? this.lastConnection,
    status: status ?? this.status,
  );
}

class AuthResult {
  final bool success;
  final String? token;
  final String? refreshToken;
  final RemoteUser? user;
  final String? error;

  const AuthResult({this.success = false, this.token, this.refreshToken, this.user, this.error});
}

class ApiResponse {
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? error;

  const ApiResponse({this.statusCode = 200, this.data, this.error});

  Map<String, dynamic> toJson() => {
    if (error != null) 'error': error,
    if (data != null) 'data': data,
  };
}
