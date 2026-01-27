import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Profil chauffeur / admin - Placeholder',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
