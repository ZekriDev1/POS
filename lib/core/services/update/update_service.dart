import 'dart:async';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'github_api.dart';
import 'download_service.dart';
import 'update_cache.dart';
import 'version_compare.dart';
import 'models/release_model.dart';

enum UpdateStatus { checking, upToDate, updateAvailable, error }

class UpdateState {
  final UpdateStatus status;
  final String? currentVersion;
  final ReleaseModel? release;
  final String? errorMessage;
  final DateTime? lastChecked;

  const UpdateState({
    this.status = UpdateStatus.checking,
    this.currentVersion,
    this.release,
    this.errorMessage,
    this.lastChecked,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    String? currentVersion,
    ReleaseModel? release,
    String? errorMessage,
    DateTime? lastChecked,
  }) {
    return UpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      release: release ?? this.release,
      errorMessage: errorMessage ?? this.errorMessage,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class UpdateService {
  final GitHubApi _gitHubApi;
  final DownloadService _downloadService;
  final UpdateCache _cache;
  String? _currentVersion;

  UpdateService({
    required String owner,
    required String repo,
    GitHubApi? gitHubApi,
    DownloadService? downloadService,
    UpdateCache? cache,
  })  : _gitHubApi = gitHubApi ?? GitHubApi(owner: owner, repo: repo),
        _downloadService = downloadService ?? DownloadService(),
        _cache = cache ?? UpdateCache();

  static UpdateService create({
    String owner = 'YOUR_USERNAME',
    String repo = 'YOUR_REPO',
  }) {
    return UpdateService(owner: owner, repo: repo);
  }

  Future<String> getCurrentVersion() async {
    if (_currentVersion != null) return _currentVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
    } catch (_) {
      _currentVersion = '1.0.0';
    }
    return _currentVersion!;
  }

  Future<UpdateState> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final release = await _gitHubApi.getLatestRelease();
      await _cache.setLastCheckDate(DateTime.now());
      await _cache.setCachedRelease(release);

      if (VersionCompare.isNewer(currentVersion, release.version)) {
        return UpdateState(
          status: UpdateStatus.updateAvailable,
          currentVersion: currentVersion,
          release: release,
          lastChecked: DateTime.now(),
        );
      }
      return UpdateState(
        status: UpdateStatus.upToDate,
        currentVersion: currentVersion,
        release: release,
        lastChecked: DateTime.now(),
      );
    } on GitHubException catch (e) {
      return UpdateState(
        status: UpdateStatus.error,
        errorMessage: e.message,
        lastChecked: DateTime.now(),
      );
    } on SocketException {
      return UpdateState(
        status: UpdateStatus.error,
        errorMessage: 'No internet connection. Please check your network.',
        lastChecked: DateTime.now(),
      );
    } on HttpException {
      return UpdateState(
        status: UpdateStatus.error,
        errorMessage: 'Could not reach GitHub. Try again later.',
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return UpdateState(
        status: UpdateStatus.error,
        errorMessage: 'Update check failed: ${e.toString()}',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<UpdateState> checkSilently() async {
    try {
      final cached = await _cache.getCachedRelease();
      final currentVersion = await getCurrentVersion();

      final skipVersion = await _cache.getSkippedVersion();
      final neverAsk = await _cache.getNeverAskAgain();
      if (neverAsk) {
        return UpdateState(status: UpdateStatus.upToDate, currentVersion: currentVersion);
      }

      if (cached != null && VersionCompare.isNewer(currentVersion, cached.version)) {
        if (skipVersion == cached.version) {
          return UpdateState(status: UpdateStatus.upToDate, currentVersion: currentVersion);
        }
        return UpdateState(
          status: UpdateStatus.updateAvailable,
          currentVersion: currentVersion,
          release: cached,
          lastChecked: await _cache.getLastCheckDate(),
        );
      }

      final state = await checkForUpdate();
      return state;
    } catch (_) {
      return UpdateState(
        status: UpdateStatus.upToDate,
        currentVersion: await getCurrentVersion(),
      );
    }
  }

  Future<String> downloadUpdate({
    required ReleaseModel release,
    required void Function(DownloadProgress) onProgress,
    bool Function()? isCancelled,
  }) async {
    final url = release.downloadUrl;
    if (url == null) {
      throw Exception('No download URL available for release ${release.version}');
    }

    final tempDir = Directory.systemTemp;
    final asset = release.installer;
    if (asset == null) throw Exception('No installable asset found');

    final filePath = '${tempDir.path}\\${asset.name}';
    await _downloadService.downloadFile(
      url: url,
      destinationPath: filePath,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    final downloadedFile = File(filePath);
    if (!await downloadedFile.exists()) {
      throw Exception('Downloaded file not found');
    }

    final fileSize = await downloadedFile.length();
    if (fileSize == 0) {
      await downloadedFile.delete();
      throw Exception('Downloaded file is empty');
    }

    return filePath;
  }

  Future<void> installUpdate(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Installer file not found: $filePath');
    }

    final name = file.uri.pathSegments.last;
    if (name.endsWith('.exe') || name.endsWith('.msi')) {
      await _installDetached(filePath, isZip: false);
    } else if (name.endsWith('.zip')) {
      final extractDir = await _extractZip(filePath);
      await _installDetached(extractDir, isZip: true);
      // Clean up the zip file
      unawaited(file.delete());
    } else {
      throw Exception('Unsupported update file type: $name');
    }
  }

  Future<String> _extractZip(String zipPath) async {
    final tempDir = Directory('${Directory.systemTemp.path}\\restropos_extract_${DateTime.now().millisecondsSinceEpoch}\\');
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    await tempDir.create(recursive: true);

    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "${tempDir.path}" -Force',
    ], runInShell: true);

    // Check if zip has a single top-level folder and adjust
    final contents = await tempDir.list().toList();
    if (contents.length == 1 && contents[0] is Directory) {
      final inner = contents[0] as Directory;
      final innerDir = inner.path;
      // Rename inner dir contents up one level
      final innerContents = await inner.list().toList();
      for (final e in innerContents) {
        final dest = '${tempDir.path}\\${e.uri.pathSegments.last}';
        if (e is Directory) {
          await e.rename(dest);
        } else if (e is File) {
          await e.rename(dest);
        }
      }
      await inner.delete();
    }

    return tempDir.path;
  }

  Future<void> _installDetached(String sourcePath, {required bool isZip}) async {
    final appExe = Platform.resolvedExecutable;
    final exeName = appExe.split('\\').last;
    final appDir = appExe.substring(0, appExe.length - exeName.length - 1);

    final ps = StringBuffer();
    ps.writeln('Start-Sleep -Seconds 2');
    ps.writeln('Remove-Item "$appDir\\${exeName}.old" -Force -ErrorAction SilentlyContinue');
    ps.writeln('Rename-Item "$appDir\\$exeName" "${exeName}.old" -Force');

    if (isZip) {
      ps.writeln('Copy-Item "$sourcePath\\*" "$appDir" -Recurse -Force');
      ps.writeln('Remove-Item "$sourcePath" -Recurse -Force -ErrorAction SilentlyContinue');
    } else {
      ps.writeln('Copy-Item "$sourcePath" "$appDir\\$exeName" -Force');
      ps.writeln('Remove-Item "$sourcePath" -Force -ErrorAction SilentlyContinue');
    }

    ps.writeln('Remove-Item "$appDir\\${exeName}.old" -Force -ErrorAction SilentlyContinue');
    ps.writeln('Start-Process "$appDir\\$exeName"');

    final scriptPath = '${Directory.systemTemp.path}\\restropos_update.ps1';
    await File(scriptPath).writeAsString(ps.toString());

    await Process.start('powershell', [
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-WindowStyle', 'Hidden',
      '-File', scriptPath,
    ], runInShell: false, mode: ProcessStartMode.detached);

    exit(0);
  }

  Future<void> skipVersion(String version) async {
    await _cache.setSkippedVersion(version);
  }

  Future<void> neverAskAgain() async {
    await _cache.setNeverAskAgain(true);
  }

  Future<bool> getAutoCheckEnabled() => _cache.getAutoCheckEnabled();
  Future<void> setAutoCheckEnabled(bool value) => _cache.setAutoCheckEnabled(value);

  void dispose() {
    _gitHubApi.dispose();
    _downloadService.dispose();
  }
}
