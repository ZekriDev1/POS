import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _boreVersion = 'v0.5.2';
const _boreZipName = 'bore-x86_64-pc-windows-msvc.zip';
const _boreUrl =
    'https://github.com/ekzhang/bore/releases/download/$_boreVersion/$_boreZipName';

class TunnelService {
  Process? _tunnelProcess;
  String? _publicUrl;
  String? _borePath;
  String? _error;
  bool _running = false;
  String _buffer = '';
  bool _downloading = false;

  bool get isRunning => _running;
  String? get publicUrl => _publicUrl;
  String? get error => _error;

  Future<String> _ensureBore() async {
    if (_borePath != null && File(_borePath!).existsSync()) return _borePath!;

    final dir = await getApplicationSupportDirectory();
    final boreDir = Directory(p.join(dir.path, 'bore'));
    if (!await boreDir.exists()) await boreDir.create(recursive: true);

    final exePath = p.join(boreDir.path, 'bore.exe');
    if (File(exePath).existsSync()) {
      _borePath = exePath;
      return exePath;
    }
    if (_downloading) throw Exception('bore is being downloaded, please wait');
    _downloading = true;
    try {
      final zipPath = p.join(boreDir.path, _boreZipName);
      final response = await http.get(Uri.parse(_boreUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download bore (HTTP ${response.statusCode})');
      }
      await File(zipPath).writeAsBytes(response.bodyBytes);

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile', '-Command',
          'Expand-Archive', '-Path', '"$zipPath"',
          '-DestinationPath', '"${boreDir.path}"', '-Force',
        ],
        runInShell: true,
      );
      if (result.exitCode != 0) {
        throw Exception('Failed to extract bore: ${result.stderr}');
      }
      await File(zipPath).delete();
      if (!File(exePath).existsSync()) {
        throw Exception('bore.exe not found after extraction');
      }
      _borePath = exePath;
      return exePath;
    } finally {
      _downloading = false;
    }
  }

  Future<bool> start({
    required int localPort,
    void Function(String url)? onUrl,
  }) async {
    if (_running) return true;
    try {
      final boreExe = await _ensureBore();
      _buffer = '';

      _tunnelProcess = await Process.start(
        boreExe,
        ['local', '$localPort', '--to', 'bore.pub'],
        runInShell: true,
      );

      _running = true;
      _publicUrl = null;
      _error = null;

      _tunnelProcess!.stdout.transform(utf8.decoder).listen((data) {
        _buffer += data;
        if (_publicUrl == null) {
          final match = RegExp(r'bore\.pub:(\d+)').firstMatch(_buffer);
          if (match != null) {
            _publicUrl = 'http://${match.group(0)}';
            onUrl?.call(_publicUrl!);
          }
        }
        if (_buffer.length > 4096) {
          _buffer = _buffer.substring(_buffer.length - 2048);
        }
      });

      _tunnelProcess!.stderr.transform(utf8.decoder).listen((data) {
        _error = (_error ?? '') + data;
        if (_error!.length > 4096) {
          _error = _error!.substring(_error!.length - 2048);
        }
      });

      _tunnelProcess!.exitCode.then((code) => _running = false);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<void> stop() async {
    if (_tunnelProcess != null) {
      _tunnelProcess!.kill();
      await _tunnelProcess!.exitCode
          .timeout(const Duration(seconds: 3), onTimeout: () => -1);
      _tunnelProcess = null;
    }
    _running = false;
    _publicUrl = null;
    _error = null;
    _buffer = '';
  }
}
