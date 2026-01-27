import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple in-memory role to simulate auth for now.
/// Replace later with real auth + claims/roles.
enum UserRole { none, admin, driver }

final roleProvider = StateProvider<UserRole>((ref) => UserRole.none);
