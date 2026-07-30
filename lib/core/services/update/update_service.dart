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
      await Process.run(filePath, [], runInShell: true);
      exit(0);
    } else if (name.endsWith('.zip')) {
      await _extractAndReplace(filePath);
    } else {
      throw Exception('Unsupported update file type: $name');
    }
  }

  Future<void> _extractAndReplace(String zipPath) async {
    final tempExtractDir = Directory('${Directory.systemTemp.path}\\restropos_update\\');
    if (await tempExtractDir.exists()) {
      await tempExtractDir.delete(recursive: true);
    }
    await tempExtractDir.create(recursive: true);

    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "${tempExtractDir.path}" -Force',
    ], runInShell: true);

    final appDir = Directory.current;
    final files = await tempExtractDir.list(recursive: true).toList();
    for (final entity in files) {
      if (entity is File) {
        final relativePath = entity.path.substring(tempExtractDir.path.length + 1);
        if (relativePath.isEmpty) continue;
        final destPath = '${appDir.path}\\$relativePath';
        final destDir = Directory(destPath).parent;
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        await entity.copy(destPath);
      }
    }

    await tempExtractDir.delete(recursive: true);
    await File(zipPath).delete();

    final exe = File('${appDir.path}\\restropos.exe');
    if (await exe.exists()) {
      await Process.run(exe.path, [], runInShell: true);
    }
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
