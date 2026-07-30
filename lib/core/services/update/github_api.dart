import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/release_model.dart';

class GitHubException implements Exception {
  final String message;
  final int? statusCode;
  GitHubException(this.message, {this.statusCode});

  @override
  String toString() => 'GitHubException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}

class GitHubApi {
  final String owner;
  final String repo;
  final http.Client _client;

  GitHubApi({
    required this.owner,
    required this.repo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.github.com';

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'RestroPOS',
      };

  Future<ReleaseModel> getLatestRelease() async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases/latest');
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ReleaseModel.fromJson(json);
    }
    if (response.statusCode == 404) {
      throw GitHubException('No releases found for $owner/$repo', statusCode: 404);
    }
    if (response.statusCode == 403) {
      throw GitHubException('GitHub API rate limit exceeded. Try again later.', statusCode: 403);
    }
    throw GitHubException('Failed to fetch latest release', statusCode: response.statusCode);
  }

  Future<List<ReleaseModel>> getAllReleases({int perPage = 10}) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases?per_page=$perPage');
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((j) => ReleaseModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw GitHubException('Failed to fetch releases', statusCode: response.statusCode);
  }

  void dispose() {
    _client.close();
  }
}
