import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth.dart';
import '../app_shell.dart';
import '../driver_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);

    switch (role) {
      case UserRole.admin:
        return const AppShell();
      case UserRole.driver:
        return const DriverShell();
      case UserRole.none:
        return _RolePicker();
    }
  }
}

class _RolePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un rôle')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sélection temporaire du rôle pour la démo.\nRemplacer par une vraie authentification plus tard.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => ref.read(roleProvider.notifier).state = UserRole.admin,
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Administrateur'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(roleProvider.notifier).state = UserRole.driver,
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Chauffeur'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
