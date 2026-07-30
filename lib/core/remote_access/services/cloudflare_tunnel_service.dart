import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class CloudflareTunnelService {
  Process? _tunnelProcess;
  String? _publicUrl;
  String? _error;
  bool _running = false;

  bool get isRunning => _running;
  String? get publicUrl => _publicUrl;
  String? get error => _error;

  Future<String> _getCloudflaredPath() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/cloudflared');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/cloudflared.exe';
  }

  Future<void> ensureCloudflared() async {
    final path = await _getCloudflaredPath();
    if (await File(path).exists()) return;

    final url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download cloudflared: HTTP ${response.statusCode}');
    }

    final file = File(path);
    await file.writeAsBytes(response.bodyBytes);

    final sha256File = File('$path.sha256');
    if (await sha256File.exists()) {
      final expectedHash = (await sha256File.readAsString()).trim().split(' ').first;
      final actualHash = sha256.convert(response.bodyBytes).toString();
      if (!_secureCompare(expectedHash, actualHash)) {
        await file.delete();
        throw Exception('cloudflared checksum mismatch');
      }
    }
  }

  Future<bool> start({required int localPort, void Function(String url)? onUrl}) async {
    if (_running) return true;
    try {
      await ensureCloudflared();
      final path = await _getCloudflaredPath();

      _tunnelProcess = await Process.start(path, [
        'tunnel',
        '--url', 'http://localhost:$localPort',
        '--no-autoupdate',
      ], runInShell: true);

      _running = true;

      _tunnelProcess!.stdout.transform(utf8.decoder).listen((data) {
        final urlMatch = RegExp(r'https://[\w-]+\.trycloudflare\.com').firstMatch(data);
        if (urlMatch != null && _publicUrl == null) {
          _publicUrl = urlMatch.group(0);
          onUrl?.call(_publicUrl!);
        }
      });

      _tunnelProcess!.stderr.transform(utf8.decoder).listen((data) {
        _error = data;
      });

      _tunnelProcess!.exitCode.then((code) {
        _running = false;
      });

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<void> stop() async {
    if (_tunnelProcess != null) {
      _tunnelProcess!.kill();
      await _tunnelProcess!.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -1);
      _tunnelProcess = null;
    }
    _running = false;
    _publicUrl = null;
  }

  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    return result == 0;
  }
}
