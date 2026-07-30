import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/release_model.dart';

class UpdateCache {
  static const _keyLastCheck = 'update_last_check';
  static const _keySkippedVersion = 'update_skipped_version';
  static const _keyCachedRelease = 'update_cached_release';
  static const _keyNeverAsk = 'update_never_ask';

  Future<DateTime?> getLastCheckDate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyLastCheck);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> setLastCheckDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCheck, date.toIso8601String());
  }

  Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySkippedVersion);
  }

  Future<void> setSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkippedVersion, version);
  }

  Future<ReleaseModel?> getCachedRelease() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCachedRelease);
    if (json == null) return null;
    try {
      return ReleaseModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setCachedRelease(ReleaseModel release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedRelease, jsonEncode(release.toJson()));
  }

  Future<void> clearCachedRelease() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedRelease);
  }

  Future<bool> getNeverAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNeverAsk) ?? false;
  }

  Future<void> setNeverAskAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNeverAsk, value);
  }

  Future<bool> getAutoCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_update_check') ?? true;
  }

  Future<void> setAutoCheckEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_update_check', value);
  }
}
