import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Requests the necessary Bluetooth permissions depending on Android version.
/// Returns true if required permissions are granted.
Future<bool> ensureBluetoothPermissions() async {
  if (!Platform.isAndroid) return true;

  // Detect Android SDK version
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final sdk = androidInfo.version.sdkInt ?? 35;

  // Request required Bluetooth permissions
  final scan = await Permission.bluetoothScan.request();
  final connect = await Permission.bluetoothConnect.request();
  final advertise = await Permission.bluetoothAdvertise.request(); // optional for our use-case

  // Some OEMs (Samsung/Xiaomi) still gate BLE scan behind location permission on Android 12+.
  // Request location on all SDKs, but only enforce it (and service on) for SDK <= 30.
  PermissionStatus location = await Permission.locationWhenInUse.request();
  bool locationServiceOk = true;
  if (sdk <= 30) {
    try {
      locationServiceOk = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceOk) {
        await Geolocator.openLocationSettings();
      }
    } catch (_) {}
  }

  // Success conditions
  final okScanConnect = scan.isGranted && connect.isGranted; // advertise optional
  final okLegacy = (sdk <= 30) && location.isGranted && locationServiceOk;
  if (okScanConnect || okLegacy) return true;

  // If permanently denied, guide user to app settings
  if (scan.isPermanentlyDenied || connect.isPermanentlyDenied || advertise.isPermanentlyDenied || (sdk <= 30 && location.isPermanentlyDenied)) {
    await openAppSettings();
  }
  return false;
}
