import 'package:firebase_core/firebase_core.dart';
import 'package:fleetguard/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/auth_gate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

Future<void> requestBluetoothPermissions() async {
  final reqs = <Permission>[];
  if (Platform.isIOS) {
    reqs.addAll([Permission.bluetooth, Permission.locationWhenInUse]);
  } else {
    reqs.addAll([
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ]);
  }

  // ignore: avoid_print
  print('>>> MAIN: Requesting permissions at startup...');
  final statuses = await reqs.request();

  for (final entry in statuses.entries) {
    // ignore: avoid_print
    print('>>> MAIN: ${entry.key} = ${entry.value}');
  }

  final allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);
  // ignore: avoid_print
  print('>>> MAIN: All permissions granted = $allGranted');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Demander les permissions au démarrage
  await requestBluetoothPermissions();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
