import 'dart:async';
import 'package:flutter/material.dart';
import 'package:restropos/core/services/update/download_service.dart';
import 'package:restropos/core/services/update/models/release_model.dart';
import 'package:restropos/core/utils/app_theme.dart';

Future<bool?> showDownloadProgressDialog(
  BuildContext context, {
  required ReleaseModel release,
  required Future<void> Function() onDownload,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DownloadProgressDialogContent(
      release: release,
      onDownload: onDownload,
    ),
  );
}

class _DownloadProgressDialogContent extends StatefulWidget {
  final ReleaseModel release;
  final Future<void> Function() onDownload;

  const _DownloadProgressDialogContent({
    required this.release,
    required this.onDownload,
  });

  @override
  State<_DownloadProgressDialogContent> createState() => _DownloadProgressDialogContentState();
}

class _DownloadProgressDialogContentState extends State<_DownloadProgressDialogContent> {
  DownloadProgress? _progress;
  bool _completed = false;
  bool _cancelled = false;
  bool _errored = false;
  String? _errorMessage;
  Timer? _etaTimer;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      await widget.onDownload();
      if (mounted && !_cancelled) {
        setState(() => _completed = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
      }
    } on DownloadCancelException {
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errored = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.cardBg,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: _errored ? _buildError() : _buildProgress(),
      ),
    );
  }

  Widget _buildProgress() {
    final p = _progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _completed
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                  : const Icon(Icons.cloud_download, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _completed ? 'Download Complete' : 'Downloading Update...',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
            ),
            if (!_completed)
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () {
                  _cancelled = true;
                  Navigator.of(context).pop(false);
                },
              ),
          ],
        ),
        if (p != null) ...[
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: p.percentage / 100,
              minHeight: 8,
              backgroundColor: AppTheme.bgColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${p.percentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(p.downloadedMb, 'Downloaded'),
                _statItem(p.speedFormatted, 'Speed'),
                _statItem(p.remainingFormatted, 'Remaining'),
                _statItem(p.etaFormatted, 'ETA'),
              ],
            ),
          ),
        ],
        if (p == null) ...[
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          const SizedBox(height: 16),
          const Text('Starting download...',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ],
        if (_completed) ...[
          const SizedBox(height: 20),
          const Text('Update downloaded successfully. Installing...',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.error_outline, color: AppTheme.danger, size: 28),
        ),
        const SizedBox(height: 14),
        const Text('Download Failed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'An unexpected error occurred',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}
