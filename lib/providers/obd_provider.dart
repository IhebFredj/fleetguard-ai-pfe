import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:fleetguard/models/obd_data.dart';
import 'package:fleetguard/services/obd_service.dart';

final obdProvider = NotifierProvider<OBDController, OBDState>(OBDController.new);

class OBDState {
  final bool isScanning;
  final bool isConnected;
  final String? connectedAddress;
  final OBDData data;
  final List<OBDChartPoint> rpmSeries;
  final List<OBDChartPoint> speedSeries;
  final String statusMessage;

  const OBDState({
    required this.isScanning,
    required this.isConnected,
    required this.connectedAddress,
    required this.data,
    required this.rpmSeries,
    required this.speedSeries,
    required this.statusMessage,
  });

  OBDState copyWith({
    bool? isScanning,
    bool? isConnected,
    String? connectedAddress,
    OBDData? data,
    List<OBDChartPoint>? rpmSeries,
    List<OBDChartPoint>? speedSeries,
    String? statusMessage,
  }) {
    return OBDState(
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      connectedAddress: connectedAddress ?? this.connectedAddress,
      data: data ?? this.data,
      rpmSeries: rpmSeries ?? this.rpmSeries,
      speedSeries: speedSeries ?? this.speedSeries,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  factory OBDState.initial() => OBDState(
        isScanning: false,
        isConnected: false,
        connectedAddress: null,
        data: OBDData.initial(),
        rpmSeries: const [],
        speedSeries: const [],
        statusMessage: '',
      );
}

class OBDChartPoint {
  final DateTime t;
  final double v;
  const OBDChartPoint(this.t, this.v);
}

class OBDController extends Notifier<OBDState> {
  late final OBDService _service;
  Timer? _pollTimer;
  DateTime? _lastTick;
  double _odometerAccumKm = 0.0;
  
  Future<bool> _ensureRuntimePermissions() async {
    final reqs = <Permission>[];
    if (Platform.isIOS) {
      // iOS flows through CoreBluetooth; permission_handler exposes bluetooth
      reqs.add(Permission.bluetooth);
      // Some iOS stacks still require location for BLE background/scan reliability
      reqs.add(Permission.locationWhenInUse);
    } else {
      // Android: request runtime perms for 12+, and location for legacy discovery
      reqs.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ]);
    }
    final statuses = await reqs.request();
    bool ok = true;
    bool permanentlyDenied = false;
    for (final s in statuses.values) {
      if (s.isPermanentlyDenied) {
        permanentlyDenied = true;
        ok = false;
      } else if (!(s.isGranted || s.isLimited)) {
        ok = false;
      }
    }
    // Some Android devices still require Location service enabled for BLE/classic discovery
    if (!permanentlyDenied && Platform.isAndroid) {
      final locService = await Permission.location.serviceStatus;
      if (!locService.isEnabled) {
        ok = false;
        state = state.copyWith(statusMessage: 'Service de localisation désactivé. Activez la localisation du téléphone pour autoriser la découverte Bluetooth.');
      }
    }
    if (!ok) {
      state = state.copyWith(statusMessage: permanentlyDenied
          ? 'Permissions Bluetooth refusées de manière permanente. Ouvrez les paramètres pour les activer.'
          : (Platform.isAndroid
              ? 'Permissions Bluetooth/Localisation refusées. Autorisez "Appareils à proximité" et "Localisation".'
              : 'Permissions Bluetooth/Localisation refusées'));
      if (permanentlyDenied) {
        // Tente d'ouvrir les paramètres de l'application
        // ignore: unawaited_futures
        openAppSettings();
      }
    }
    return ok;
  }

  @override
  OBDState build() {
    _service = OBDService();
    ref.onDispose(_cleanup);
    return OBDState.initial();
  }

  Future<List<Map<String, String>>> listBonded() async {
    state = state.copyWith(isScanning: true, statusMessage: 'Activation Bluetooth...');
    try {
      // ignore: avoid_print
      print('>>> listBonded() called');
      final permsOk = await _ensureRuntimePermissions();
      if (!permsOk) {
        state = state.copyWith(statusMessage: 'Permissions Bluetooth refusées');
        // ignore: avoid_print
        print('>>> listBonded: permissions not granted');
        return [];
      }
      final ok = await _service.ensureEnabled();
      if (!ok) {
        state = state.copyWith(statusMessage: 'Bluetooth désactivé');
        // ignore: avoid_print
        print('>>> listBonded: bluetooth OFF');
        return [];
      }
      // Classic bonded devices
      final classic = await _service.getBondedDevices();
      final classicMaps = classic
          .map((d) => {
                'name': d.name ?? d.address,
                'address': 'classic:${d.address}',
              })
          .toList();
      // BLE scan (short window)
      final bleResults = await _service.scanBle(timeout: const Duration(seconds: 4));
      final bleMaps = bleResults
          .map((m) => {
                'name': m['name'] ?? m['id'] ?? 'BLE Device',
                'address': 'ble:${m['id']}',
              })
          .toList();
      // Merge, classic first, then BLE; de-dup by address
      final merged = <String, Map<String, String>>{};
      for (final d in [...classicMaps, ...bleMaps]) {
        merged[d['address']!] = d;
      }
      return merged.values.toList();
    } catch (e) {
      state = state.copyWith(statusMessage: 'Erreur Bluetooth: $e');
      return [];
    } finally {
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> connectTo(String address) async {
    state = state.copyWith(isScanning: true, statusMessage: 'Connexion...');
    try {
      // ignore: avoid_print
      print('>>> connectTo appelé avec : $address');
      final permsOk = await _ensureRuntimePermissions();
      if (!permsOk) {
        state = state.copyWith(statusMessage: 'Permissions Bluetooth refusées');
        // ignore: avoid_print
        print('>>> connectTo: permissions not granted');
        return;
      }
      final ok = await _service.ensureEnabled();
      if (!ok) {
        state = state.copyWith(statusMessage: 'Bluetooth désactivé');
        // ignore: avoid_print
        print('>>> connectTo: bluetooth OFF');
        return;
      }
      // ignore: avoid_print
      print('>>> connectTo: calling service.connect');
      await _service.connect(address);
      // ignore: avoid_print
      print('>>> connectTo: service.connect OK');
      // Identify adapter and handshake with ECU before declaring connected
      String adapter = '';
      try {
        adapter = await _service.identifyAdapter();
      } catch (_) {}
      final ecuOk = await _service.handshakeEcu().catchError((_) => false);
      // ignore: avoid_print
      print('>>> connectTo: handshakeEcu = $ecuOk');
      if (!ecuOk) {
        await _service.disconnect();
        state = state.copyWith(
          statusMessage: 'ECU non détectée. Vérifiez le contact, le branchement OBD2 et l\'adaptateur.',
          isConnected: false,
          connectedAddress: null,
        );
        // ignore: avoid_print
        print('>>> connectTo: ECU handshake failed');
        return;
      }
      state = state.copyWith(
        isConnected: true,
        connectedAddress: address,
        statusMessage: adapter.isNotEmpty ? 'Connecté ($adapter)' : 'Connecté',
      );
      // ignore: avoid_print
      print('>>> connectTo: CONNECTED');
      _startPolling();
    } catch (e) {
      state = state.copyWith(statusMessage: 'Erreur connexion: $e', isScanning: false);
      // ignore: avoid_print
      print('>>> connectTo: exception: $e');
    } finally {
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    _stopPolling();
    state = OBDState.initial();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => pollOnce());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> pollOnce() async {
    if (!_service.isConnected) return;
    try {
      final rpmRead = await _service.readRpm();
      final spdRead = await _service.readSpeedKmh();
      final tempRead = await _service.readEngineTempC();
      final fuelRead = await _service.readFuelLevelPercent();
      final rpm = rpmRead ?? state.data.rpm;
      final spd = spdRead ?? state.data.speedKmh;
      final temp = tempRead ?? state.data.engineTempC;
      final fuel = fuelRead ?? state.data.fuelLevelPercent;
      // Oil pressure and consumption not standard on all PIDs, simulate for now
      final oil = (1.5 + (rpm / 6000)).clamp(0, 6).toDouble();
      // Try to compute fuel rate L/h from PID 015E; fallback via MAF if available.
      final fuelRateLhPid = await _service.readFuelRate015E();
      final mafGps = await _service.readMAF0110();
      double? fuelRateLh;
      if (fuelRateLhPid != null && fuelRateLhPid > 0) {
        fuelRateLh = fuelRateLhPid;
      } else if (mafGps != null && mafGps > 0) {
        // Approx for essence; adjust AFR/density later based on fuel type when known.
        const afr = 14.7; // stoichiometric
        const densityGPerMl = 0.745; // gasoline
        final fuelGPerS = mafGps / afr;
        final fuelLPerS = fuelGPerS / densityGPerMl / 1000.0;
        fuelRateLh = fuelLPerS * 3600.0;
      }
      final consoPrev = state.data.instantConsumptionLPer100;
      final conso = (spd > 0)
          ? ((fuelRateLh ?? (consoPrev * spd / 100)).clamp(0, 50.0)) * (100 / spd)
          : consoPrev;

      // Extended sensors
      final engineLoad = await _service.readEngineLoad0104();
      final fuelPressure = await _service.readFuelPressure010A();
      final map = await _service.readMAP010B();
      final iat = await _service.readIAT010F();
      final tps = await _service.readTPS0111();
      final runTime = await _service.readRunTime011F();
      final distSinceDtc = await _service.readDistanceSinceDtcClear0131();
      final fuelType = await _service.readFuelType0151();
      final oilTemp = await _service.readOilTemp015C();
      final fuelTemp = await _service.readFuelTemp015F();

      final now = DateTime.now();
      // Odometer: try PID 01A6; if null, integrate speed over time
      final odoPid = await _service.readOdometer01A6();
      if (odoPid != null) {
        _odometerAccumKm = odoPid;
        _lastTick = now;
      } else {
        if (_lastTick != null) {
          final dtSec = now.difference(_lastTick!).inMilliseconds / 1000.0;
          _odometerAccumKm += ((spd) * dtSec) / 3600.0;
        }
        _lastTick = now;
      }

      final newData = state.data.copyWith(
        rpm: rpm,
        speedKmh: spd,
        engineTempC: temp,
        fuelLevelPercent: fuel,
        oilPressureBar: oil,
        instantConsumptionLPer100: conso,
        distanceKm: state.data.distanceKm + max(0.0, spd) / 3600,
        odometerKm: _odometerAccumKm,
        engineOk: (temp < 100) && (conso < 20),
        timestamp: now,
        engineLoadPct: engineLoad,
        fuelPressureKpa: fuelPressure,
        mapKpa: map,
        iatC: iat,
        tpsPct: tps,
        runTimeSec: runTime,
        distanceSinceDtcKm: distSinceDtc,
        fuelType: fuelType,
        oilTempC: oilTemp,
        fuelRateLh: fuelRateLh,
        fuelTempC: fuelTemp,
        mafGps: mafGps,
      );

      final rpmPts = [...state.rpmSeries, OBDChartPoint(now, rpm.toDouble())];
      final spdPts = [...state.speedSeries, OBDChartPoint(now, spd.toDouble())];
      // Keep last 120s
      final cutoff = now.subtract(const Duration(seconds: 120));
      state = state.copyWith(
        data: newData,
        rpmSeries: rpmPts.where((p) => p.t.isAfter(cutoff)).toList(),
        speedSeries: spdPts.where((p) => p.t.isAfter(cutoff)).toList(),
      );
    } catch (e) {
      state = state.copyWith(statusMessage: 'Erreur lecture: $e');
    }
  }

  Future<void> clearDTC() async {
    // Mode 04 clears DTCs
    try {
      await _service.clearDTC();
      state = state.copyWith(statusMessage: 'DTC effacés');
    } catch (e) {
      state = state.copyWith(statusMessage: 'Échec effacement DTC: $e');
    }
  }

  Future<void> sendToServer(String camionId, Uri endpoint) async {
    final payload = state.data.toJson(camionId: camionId);
    await http.post(endpoint, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
  }

  Future<void> startDemo() async {
    // Simulate values when no device
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      final now = DateTime.now();
      final rng = Random();
      final rpm = 800 + rng.nextInt(2500);
      final spd = rng.nextInt(90).toDouble();
      final temp = 70 + rng.nextInt(35);
      final fuel = max(0, state.data.fuelLevelPercent - rng.nextInt(2));
      final oil = 1.2 + rng.nextDouble() * 1.2;
      final conso = 6 + rng.nextDouble() * 8;
      final newData = state.data.copyWith(
        rpm: rpm,
        speedKmh: spd,
        engineTempC: temp.toDouble(),
        fuelLevelPercent: fuel,
        oilPressureBar: oil,
        instantConsumptionLPer100: conso,
        distanceKm: state.data.distanceKm + spd / 3600,
        engineOk: temp < 100 && conso < 18,
        timestamp: now,
      );
      final rpmPts = [...state.rpmSeries, OBDChartPoint(now, rpm.toDouble())];
      final spdPts = [...state.speedSeries, OBDChartPoint(now, spd.toDouble())];
      final cutoff = now.subtract(const Duration(seconds: 120));
      state = state.copyWith(
        data: newData,
        rpmSeries: rpmPts.where((p) => p.t.isAfter(cutoff)).toList(),
        speedSeries: spdPts.where((p) => p.t.isAfter(cutoff)).toList(),
        isConnected: false,
        statusMessage: 'Mode démo',
      );
    });
  }

  void _cleanup() {
    _stopPolling();
    _service.disconnect();
  }
}
