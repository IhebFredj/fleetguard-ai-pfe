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
  await reqs.request();
}

Future<void> main(dynamic Firebase) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  WidgetsFlutterBinding.ensureInitialized();
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
