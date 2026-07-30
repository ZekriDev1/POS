import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final Duration elapsed;

  DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.speedBytesPerSec,
    required this.elapsed,
  });

  double get percentage => totalBytes > 0 ? (receivedBytes / totalBytes * 100) : 0;
  String get downloadedMb => '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  String get totalMb => '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  String get speedFormatted {
    if (speedBytesPerSec >= 1024 * 1024) {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (speedBytesPerSec >= 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
  }

  String get remainingFormatted {
    final remaining = totalBytes - receivedBytes;
    if (remaining <= 0) return '0 B';
    if (remaining >= 1024 * 1024) {
      return '${(remaining / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (remaining >= 1024) {
      return '${(remaining / 1024).toStringAsFixed(0)} KB';
    }
    return '$remaining B';
  }

  String get etaFormatted {
    final remaining = totalBytes - receivedBytes;
    if (remaining <= 0 || speedBytesPerSec <= 0) return '--';
    final seconds = (remaining / speedBytesPerSec).round();
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }
}

class DownloadCancelException implements Exception {
  final String message;
  DownloadCancelException([this.message = 'Download cancelled']);
}

class DownloadService {
  final http.Client _client;

  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> downloadFile({
    required String url,
    required String destinationPath,
    required void Function(DownloadProgress) onProgress,
    bool Function()? isCancelled,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll({
      'User-Agent': 'RestroPOS',
      'Accept': '*/*',
    });

    final response = await _client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Download failed with status ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    final file = File(destinationPath);
    final sink = file.openWrite(mode: FileMode.write);
    int received = 0;
    final stopwatch = Stopwatch()..start();

    try {
      await for (final chunk in response.stream) {
        if (isCancelled != null && isCancelled()) {
          throw DownloadCancelException();
        }
        sink.add(chunk);
        received += chunk.length;
        final elapsed = stopwatch.elapsed;
        final speed = elapsed.inSeconds > 0 ? received / elapsed.inSeconds : 0.0;
        onProgress(DownloadProgress(
          receivedBytes: received,
          totalBytes: contentLength,
          speedBytesPerSec: speed,
          elapsed: elapsed,
        ));
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
      await file.delete();
      rethrow;
    }
    await sink.close();
    stopwatch.stop();
    return destinationPath;
  }

  void dispose() {
    _client.close();
  }
}
