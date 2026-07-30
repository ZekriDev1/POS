class VersionCompare {
  VersionCompare._();

  static int compare(String a, String b) {
    final partsA = _parse(a);
    final partsB = _parse(b);
    for (int i = 0; i < 3; i++) {
      if (partsA[i] != partsB[i]) {
        return partsA[i].compareTo(partsB[i]);
      }
    }
    return 0;
  }

  static bool isNewer(String current, String latest) {
    return compare(current, latest) < 0;
  }

  static bool isOlder(String current, String latest) {
    return compare(current, latest) > 0;
  }

  static bool isEqual(String a, String b) {
    return compare(a, b) == 0;
  }

  static List<int> _parse(String version) {
    final cleaned = version.trim().replaceFirst('v', '').replaceFirst('V', '');
    final parts = cleaned.split('.');
    return [
      _parseInt(parts, 0),
      _parseInt(parts, 1),
      _parseInt(parts, 2),
    ];
  }

  static int _parseInt(List<String> parts, int index) {
    if (index >= parts.length) return 0;
    final num = parts[index].replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(num) ?? 0;
  }
}
