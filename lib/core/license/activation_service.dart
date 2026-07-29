import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:restropos/core/license/license_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivationService {
  LicenseModel? _cached;

  Future<String> get _activationPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'activation.json');
  }

  Future<LicenseModel> load() async {
    if (_cached != null) return _cached!;
    try {
      final file = File(await _activationPath);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        _cached = LicenseModel.fromJson(json);
        return _cached!;
      }
    } catch (_) {}
    _cached = const LicenseModel(activated: false, license: '', device: '');
    return _cached!;
  }

  Future<void> save(LicenseModel license) async {
    _cached = license;
    final file = File(await _activationPath);
    await file.writeAsString(jsonEncode(license.toJson()));
  }

  Future<bool> isActivated() async {
    final license = await load();
    return license.activated;
  }

  Future<String> getDeviceId() async {
    final license = await load();
    if (license.device.isNotEmpty) return license.device;
    final id = _generateDeviceId();
    await save(license.copyWith(device: id));
    return id;
  }

  String _generateDeviceId() {
    final info = <String>[
      Platform.operatingSystem,
      Platform.operatingSystemVersion,
      Platform.localHostname,
    ];
    return info.join('-');
  }

  Future<ActivationResult> activate(String licenseKey) async {
    try {
      final deviceId = await getDeviceId();
      final response = await Supabase.instance.client.functions.invoke(
        'validate-license',
        body: {
          'license_key': licenseKey,
          'device_id': deviceId,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data != null && data['valid'] == true) {
        await save(LicenseModel(
          activated: true,
          license: licenseKey,
          device: deviceId,
        ));
        return ActivationResult(success: true);
      }
      return ActivationResult(
        success: false,
        message: data?['message'] ?? 'Invalid license key',
      );
    } catch (e) {
      return ActivationResult(
        success: false,
        message: 'Activation failed: $e',
      );
    }
  }
}

class ActivationResult {
  final bool success;
  final String? message;
  const ActivationResult({required this.success, this.message});
}
