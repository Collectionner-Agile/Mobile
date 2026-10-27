import '../../../core/utils/json.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    this.avatarUrl,
    this.bio,
    this.location,
    this.memberSince,
    this.hasLocalPassword = true,
  });

  final int id;
  final String username;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final DateTime? memberSince;
  final bool hasLocalPassword;

  String get initial {
    final source = name.isNotEmpty ? name : username;
    return source.isEmpty ? '?' : String.fromCharCode(source.runes.first).toUpperCase();
  }

  factory AppUser.fromJson(JsonMap json) => AppUser(
    id: json.requireInt('id'),
    username: json.stringOrNull('username') ?? '',
    name: json.stringOrNull('name') ?? json.stringOrNull('username') ?? '',
    email: json.stringOrNull('email'),
    avatarUrl: json.stringOrNull('avatarUrl'),
    bio: json.stringOrNull('bio'),
    location: json.stringOrNull('location'),
    memberSince: json.dateOrNull('memberSince'),
    hasLocalPassword: json.boolOr('hasLocalPassword', fallback: true),
  );

  JsonMap toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'location': location,
    'memberSince': memberSince?.toUtc().toIso8601String(),
    'hasLocalPassword': hasLocalPassword,
  };
}
