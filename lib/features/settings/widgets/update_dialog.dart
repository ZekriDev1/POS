import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restropos/core/services/update/models/release_model.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'download_progress_dialog.dart';

Future<bool?> showUpdateDialog(
  BuildContext context, {
  required String currentVersion,
  required ReleaseModel release,
  required Future<void> Function() onUpdateNow,
  required Future<void> Function() onSkip,
  required Future<void> Function() onNeverAsk,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UpdateDialogContent(
      currentVersion: currentVersion,
      release: release,
      onUpdateNow: onUpdateNow,
      onSkip: onSkip,
      onNeverAsk: onNeverAsk,
    ),
  );
}

class _UpdateDialogContent extends StatefulWidget {
  final String currentVersion;
  final ReleaseModel release;
  final Future<void> Function() onUpdateNow;
  final Future<void> Function() onSkip;
  final Future<void> Function() onNeverAsk;

  const _UpdateDialogContent({
    required this.currentVersion,
    required this.release,
    required this.onUpdateNow,
    required this.onSkip,
    required this.onNeverAsk,
  });

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _updating = false;

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.cardBg,
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.system_update, color: AppTheme.primary, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'New Update Available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow('Current Version', widget.currentVersion),
                  const SizedBox(height: 10),
                  _infoRow('Latest Version', widget.release.version),
                  const SizedBox(height: 10),
                  _infoRow('Release Date', _formatDate(widget.release.publishedAt)),
                  if (widget.release.fileSize != null) ...[
                    const SizedBox(height: 10),
                    _infoRow('File Size', _formatSize(widget.release.fileSize!)),
                  ],
                ],
              ),
            ),
            if (widget.release.body.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Release Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.release.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMain,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _updating
                        ? null
                        : () async {
                            await widget.onSkip();
                            if (context.mounted) Navigator.of(context).pop(false);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    child: const Text('Later', style: TextStyle(color: AppTheme.textMain)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _updating
                        ? null
                        : () async {
                            await widget.onNeverAsk();
                            if (context.mounted) Navigator.of(context).pop(false);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    child: const Text('Never Ask Again',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _updating
                        ? null
                        : () async {
                            setState(() => _updating = true);
                            try {
                              final result = await showDownloadProgressDialog(
                                context,
                                release: widget.release,
                                onDownload: widget.onUpdateNow,
                              );
                              if (result == true && context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            } finally {
                              if (mounted) setState(() => _updating = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _updating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Update Now',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
