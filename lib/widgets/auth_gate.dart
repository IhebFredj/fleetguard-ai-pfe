import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/login_page.dart';
import '../core/auth.dart';
import '../core/auth_state.dart';
import '../app_shell.dart';
import '../driver_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final role = ref.watch(roleProvider);

    // Show loading while checking auth state
    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Redirect to login if not authenticated
    if (!authState.isAuthenticated) {
      return const LoginPage();
    }

    // Route based on user role
    switch (role) {
      case UserRole.admin:
        return const AppShell();
      case UserRole.driver:
        return const DriverShell();
      case UserRole.none:
        return const LoginPage();
    }
  }
}
