import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restropos/core/l10n/translations.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/remote_access/models/remote_access_models.dart';
import 'package:restropos/core/remote_access/services/remote_access_service.dart';

final remoteAccessProvider = StateNotifierProvider<RemoteAccessNotifier, RemoteAccessState>((ref) {
  final db = ref.read(databaseProvider);
  return RemoteAccessNotifier(db);
});

class RemoteAccessNotifier extends StateNotifier<RemoteAccessState> {
  final AppDatabase _db;
  RemoteAccessService? _service;
  StreamSubscription? _sub;

  RemoteAccessNotifier(this._db) : super(const RemoteAccessState());

  RemoteAccessService? get service => _service;

  Future<void> initialize() async {
    _service = RemoteAccessService(_db);
    await _service!.initialize();
    _sub = _service!.stateStream.listen((s) {
      if (mounted) state = s;
    });
    await _service!.start();
  }

  Future<void> toggle(bool enable) async {
    if (_service == null) return;
    if (enable) {
      await _service!.start();
    } else {
      await _service!.stop();
    }
  }

  Future<void> restartTunnel() async {
    await _service?.restartTunnel();
  }

  Future<List<RemoteUser>> getUsers() async {
    if (_service == null) return [];
    return _service!.tables.getAllUsers();
  }

  Future<String> createUser(String username, String password, String role) async {
    if (_service == null) return '';
    return _service!.tables.createUser(username, password, role);
  }

  Future<void> updateUserPassword(String id, String password) async {
    await _service?.tables.updateUserPassword(id, password);
  }

  Future<void> updateUserRole(String id, String role) async {
    await _service?.tables.updateUserRole(id, role);
  }

  Future<void> toggleUserActive(String id) async {
    await _service?.tables.toggleUserActive(id);
  }

  Future<void> deleteUser(String id) async {
    await _service?.tables.deleteUser(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service?.dispose();
    super.dispose();
  }
}

class RemoteAccessScreen extends ConsumerStatefulWidget {
  const RemoteAccessScreen({super.key});

  @override
  ConsumerState<RemoteAccessScreen> createState() => _RemoteAccessScreenState();
}

class _RemoteAccessScreenState extends ConsumerState<RemoteAccessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remoteAccessProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteAccessProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.t('remoteAccess'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            const SizedBox(height: 24),
            _buildStatusCard(state),
            const SizedBox(height: 16),
            _buildConnectionDetails(state),
            if (state.enabled) ...[const SizedBox(height: 16), _buildQrCard(state)],
            if (state.enabled) ...[const SizedBox(height: 16), _buildActiveSessionsCard(state)],
            const SizedBox(height: 16),
            _buildUsersCard(),
            const SizedBox(height: 16),
            _buildActionsCard(state),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(RemoteAccessState state) {
    final statusColor = state.enabled
        ? (state.tunnelRunning ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
        : AppTheme.textMuted;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.cloud, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(ref.t('remoteAccess'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const Spacer(),
              Switch(
                value: state.enabled,
                onChanged: (v) => ref.read(remoteAccessProvider.notifier).toggle(v),
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(ref.t('tunnelStatus'), state.status, valueColor: statusColor),
          const SizedBox(height: 8),
          _infoRow(ref.t('httpServer'), state.serverRunning ? ref.t('running') : ref.t('stopped'),
              valueColor: state.serverRunning ? const Color(0xFF10B981) : AppTheme.textMuted),
          if (state.lastConnection != null) ...[
            const SizedBox(height: 8),
            _infoRow(ref.t('lastConnection'), _formatDate(state.lastConnection!)),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionDetails(RemoteAccessState state) {
    final notifier = ref.read(remoteAccessProvider.notifier);
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.link, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(ref.t('connectionDetails'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(ref.t('localIp'), state.localIp ?? '--'),
          const SizedBox(height: 8),
          _infoRow(ref.t('localPort'), '${state.localPort}'),
          const SizedBox(height: 8),
          _infoRow(ref.t('publicUrl'), state.publicUrl ?? '--'),
          if (state.publicUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _iconBtn(Icons.copy, ref.t('copyUrl'), () {
                  Clipboard.setData(ClipboardData(text: state.publicUrl!));
                }),
                const SizedBox(width: 8),
                _iconBtn(Icons.open_in_new, ref.t('openUrl'), () {
                  launchUrl(Uri.parse(state.publicUrl!));
                }),
                const SizedBox(width: 8),
                _iconBtn(Icons.refresh, ref.t('refreshUrl'), () {
                  notifier.restartTunnel();
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrCard(RemoteAccessState state) {
    final url = state.publicUrl ?? 'http://${state.localIp ?? 'localhost'}:${state.localPort}';
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.qr_code, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(ref.t('qrCode'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(url, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(ref.t('scanToAccess'), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsCard(RemoteAccessState state) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(ref.t('connectedDevices'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${state.activeUsers} ${ref.t('active')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.connectedSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text(ref.t('noActiveSessions'), style: const TextStyle(color: AppTheme.textMuted))),
            )
          else
            ...state.connectedSessions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${s.device}${s.browser.isNotEmpty ? ' · $s.browser' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              Text('${s.ipAddress}${s.country != null ? ' · ${s.country}' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              Text('${_formatDate(s.loginTime)} · ${_formatDuration(s.duration)}',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: AppTheme.danger),
                          onPressed: () => _disconnectSession(s.id),
                          tooltip: ref.t('disconnect'),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildActionsCard(RemoteAccessState state) {
    final notifier = ref.read(remoteAccessProvider.notifier);
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.settings, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(ref.t('actions'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.enabled ? () => notifier.restartTunnel() : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(ref.t('restartTunnel')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          if (state.enabled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => notifier.toggle(false),
                icon: const Icon(Icons.stop, size: 18),
                label: Text(ref.t('stopRemoteAccess')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersCard() {
    final notifier = ref.read(remoteAccessProvider.notifier);
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_add, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(ref.t('users'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                onPressed: () => _showUserDialog(),
                tooltip: ref.t('addUser'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _UserList(notifier: notifier, onEdit: (user) => _showUserDialog(user: user)),
        ],
      ),
    );
  }

  Future<void> _showUserDialog({RemoteUser? user}) async {
    final notifier = ref.read(remoteAccessProvider.notifier);
    final usernameController = TextEditingController(text: user?.username);
    final passwordController = TextEditingController();
    final roleController = TextEditingController(text: user?.role.name ?? 'cashier');
    final isNew = user == null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isNew ? ref.t('createUser') : ref.t('editUser')),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(labelText: ref.t('username'), border: const OutlineInputBorder()),
                  enabled: isNew,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: isNew ? ref.t('password') : ref.t('newPasswordKeep'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: roleController.text,
                  decoration: InputDecoration(labelText: ref.t('role'), border: const OutlineInputBorder()),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                  onChanged: (v) => roleController.text = v ?? 'cashier',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.t('cancel'))),
            TextButton(
              onPressed: () async {
                final username = usernameController.text.trim();
                final password = passwordController.text;
                final role = roleController.text;
                if (username.isEmpty) return;
                if (isNew && password.isEmpty) return;
                Navigator.pop(ctx);
                if (isNew) {
                  await notifier.createUser(username, password, role);
                } else {
                  if (password.isNotEmpty) await notifier.updateUserPassword(user.id, password);
                  await notifier.updateUserRole(user.id, role);
                }
              },
              child: Text(isNew ? ref.t('create') : ref.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, softWrap: true, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textMain)),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
      ),
    );
  }

  void _disconnectSession(String sessionId) async {
    final service = ref.read(remoteAccessProvider.notifier).service;
    if (service != null) {
      await service.auth.disconnectSession(sessionId);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

class _UserList extends ConsumerWidget {
  final RemoteAccessNotifier notifier;
  final void Function(RemoteUser) onEdit;

  const _UserList({required this.notifier, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<RemoteUser>>(
      future: notifier.getUsers(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }
        final users = snap.data ?? [];
        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(ref.t('noUsers'), style: const TextStyle(color: AppTheme.textMuted))),
          );
        }
        return Column(
          children: users.map((u) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(u.role.name, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ),
                            if (!u.isActive) ...[
                              const SizedBox(width: 6),
                              Text(ref.t('disabledBadge'), style: const TextStyle(fontSize: 10, color: AppTheme.danger)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(ref.t('createdOn', {'date': _formatDateShort(u.createdAt)}),
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: AppTheme.textMuted),
                    onPressed: () => onEdit(u),
                    tooltip: ref.t('edit'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16, color: AppTheme.danger),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(ref.t('deleteUser')),
                          content: Text(ref.t('deleteUserConfirm', {'name': u.username})),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(ref.t('cancel'))),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ref.t('delete'), style: const TextStyle(color: AppTheme.danger))),
                          ],
                        ),
                      );
                      if (confirm == true) await notifier.deleteUser(u.id);
                    },
                    tooltip: ref.t('delete'),
                  ),
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
