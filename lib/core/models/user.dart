import 'package:flutter/foundation.dart';

/// User model representing the authenticated user
@immutable
class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.isOnline = true,
    this.lastSeen,
  });

  /// Get initials from the user's name
  String get initials {
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email;
  }

  @override
  int get hashCode => Object.hash(id, name, email);
}
