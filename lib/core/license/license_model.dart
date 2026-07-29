class LicenseModel {
  final bool activated;
  final String license;
  final String device;

  const LicenseModel({
    required this.activated,
    required this.license,
    required this.device,
  });

  Map<String, dynamic> toJson() => {
        'activated': activated,
        'license': license,
        'device': device,
      };

  factory LicenseModel.fromJson(Map<String, dynamic> json) => LicenseModel(
        activated: json['activated'] as bool? ?? false,
        license: json['license'] as String? ?? '',
        device: json['device'] as String? ?? '',
      );

  LicenseModel copyWith({
    bool? activated,
    String? license,
    String? device,
  }) =>
      LicenseModel(
        activated: activated ?? this.activated,
        license: license ?? this.license,
        device: device ?? this.device,
      );
}
