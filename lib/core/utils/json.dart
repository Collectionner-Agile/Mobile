typedef JsonMap = Map<String, dynamic>;

/// Tolerant readers for backend JSON. They never throw on a missing optional
/// field; required fields go through [requireInt]/[requireString].
extension JsonRead on JsonMap {
  int? intOrNull(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int requireInt(String key) {
    final value = intOrNull(key);
    if (value == null) throw FormatException('Missing integer "$key"');
    return value;
  }

  double? doubleOrNull(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? stringOrNull(String key) {
    final value = this[key];
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  String requireString(String key) {
    final value = stringOrNull(key);
    if (value == null) throw FormatException('Missing string "$key"');
    return value;
  }

  bool boolOr(String key, {bool fallback = false}) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  DateTime? dateOrNull(String key) {
    final value = stringOrNull(key);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  List<JsonMap> objects(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  List<String> strings(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  JsonMap? objectOrNull(String key) {
    final value = this[key];
    return value is Map<String, dynamic> ? value : null;
  }
}

List<T> parseList<T>(Object? data, T Function(JsonMap json) parser) {
  if (data is! List) throw const FormatException('Expected a JSON array');
  return data.whereType<Map<String, dynamic>>().map(parser).toList(growable: false);
}

T parseObject<T>(Object? data, T Function(JsonMap json) parser) {
  if (data is! Map<String, dynamic>) throw const FormatException('Expected a JSON object');
  return parser(data);
}
