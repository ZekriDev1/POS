

class ReleaseModel {
  final String tagName;
  final String name;
  final String body;
  final DateTime publishedAt;
  final List<ReleaseAsset> assets;

  ReleaseModel({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.assets,
  });

  String get version => tagName.startsWith('v') ? tagName.substring(1) : tagName;

  ReleaseAsset? get installer {
    if (assets.isEmpty) return null;
    final exe = assets.where((a) => a.name.endsWith('.exe') || a.name.endsWith('.msi')).toList();
    if (exe.isNotEmpty) return exe.first;
    final zip = assets.where((a) => a.name.endsWith('.zip')).toList();
    return zip.isNotEmpty ? zip.first : null;
  }

  String? get downloadUrl => installer?.browserDownloadUrl;

  int? get fileSize => installer?.size;

  factory ReleaseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['assets'] as List<dynamic>?)
            ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    return ReleaseModel(
      tagName: json['tag_name'] as String? ?? '0.0.0',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      assets: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'tag_name': tagName,
        'name': name,
        'body': body,
        'published_at': publishedAt.toIso8601String(),
        'assets': assets.map((a) => a.toJson()).toList(),
      };

  @override
  String toString() => 'ReleaseModel($version)';
}

class ReleaseAsset {
  final String name;
  final int size;
  final String browserDownloadUrl;
  final String contentType;

  ReleaseAsset({
    required this.name,
    required this.size,
    required this.browserDownloadUrl,
    required this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'browser_download_url': browserDownloadUrl,
        'content_type': contentType,
      };

  @override
  String toString() => 'ReleaseAsset($name, ${_formatSize(size)})';

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
