import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restropos/core/services/update/update_providers.dart';
import 'package:restropos/core/services/update/update_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'update_dialog.dart';
import 'package:restropos/core/l10n/translations.dart';

class UpdateSettingsSection extends ConsumerStatefulWidget {
  const UpdateSettingsSection({super.key});

  @override
  ConsumerState<UpdateSettingsSection> createState() => _UpdateSettingsSectionState();
}

class _UpdateSettingsSectionState extends ConsumerState<UpdateSettingsSection> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _triggerSilentCheck();
  }

  Future<void> _triggerSilentCheck() async {
    ref.read(updateCheckProvider);
  }

  Future<void> _manualCheck() async {
    setState(() => _checking = true);
    try {
      final service = ref.read(updateServiceProvider);
      final state = await service.checkForUpdate();
      ref.read(updateStateProvider.notifier).state = state;
      _showResult(state);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showResult(UpdateState state) {
    if (!mounted) return;
    switch (state.status) {
      case UpdateStatus.upToDate:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('upToDateSnack'))),
        );
      case UpdateStatus.updateAvailable:
        _showUpdateDialog(state);
      case UpdateStatus.error:
        final msg = state.errorMessage;
        final translated = msg != null
            ? _translateError(msg)
            : context.t('updateCheckFailed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translated)),
        );
      case UpdateStatus.checking:
        break;
    }
  }

  Future<void> _showUpdateDialog(UpdateState state) async {
    final service = ref.read(updateServiceProvider);
    final release = state.release;
    if (release == null) return;

    final result = await showUpdateDialog(
      context,
      currentVersion: state.currentVersion ?? '--',
      release: release,
      onUpdateNow: () async {
        final filePath = await service.downloadUpdate(
          release: release,
          onProgress: (progress) {},
        );
        await service.installUpdate(filePath);
      },
      onSkip: () => service.skipVersion(release.version),
      onNeverAsk: () => service.neverAskAgain(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('updateRestarting'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateStateProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(context.t('appUpdates'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ],
          ),
          const SizedBox(height: 20),
          _infoTile(context.t('currentVersion'), state.currentVersion ?? '--'),
          const SizedBox(height: 10),
          _infoTile(context.t('latestVersion'), _latestVersionText(state)),
          const SizedBox(height: 10),
          _infoTile(context.t('lastChecked'), _lastCheckedText(state)),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('autoCheck'),
                style: const TextStyle(fontSize: 14, color: AppTheme.textMain)),
            subtitle: Text(context.t('autoCheckSub'),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            value: true,
            activeColor: AppTheme.primary,
            onChanged: (val) async {
              final service = ref.read(updateServiceProvider);
              await service.setAutoCheckEnabled(val);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checking ? null : _manualCheck,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_checking ? context.t('checking') : context.t('checkUpdates'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
      ],
    );
  }

  String _latestVersionText(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.checking:
        return context.t('checking');
      case UpdateStatus.upToDate:
        return state.release?.version ?? context.t('upToDate');
      case UpdateStatus.updateAvailable:
        return state.release?.version ?? '--';
      case UpdateStatus.error:
        return '--';
    }
  }

  String _translateError(String msg) {
    if (msg.startsWith('No internet connection')) return context.t('noInternet');
    if (msg.startsWith('Could not reach GitHub')) return context.t('noGitHub');
    if (msg.startsWith('Update check failed')) {
      final error = msg.substring('Update check failed: '.length);
      return context.t('updateError', {'error': error});
    }
    return msg;
  }

  String _lastCheckedText(UpdateState state) {
    final last = state.lastChecked;
    if (last == null) return context.t('never');
    return DateFormat('MMM dd, yyyy HH:mm').format(last);
  }
}
