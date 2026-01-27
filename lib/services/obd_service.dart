import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

class OBDService {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  // Broadcast input for classic
  Stream<List<int>>? _classicInput;

  // BLE state
  ble.BluetoothDevice? _bleDevice;
  ble.BluetoothCharacteristic? _bleWrite;
  ble.BluetoothCharacteristic? _bleNotify;
  // Broadcast input for BLE
  Stream<List<int>>? _bleInput;
  // BLE notify subscription is managed per-request; no persistent sub needed

  Future<bool> get isEnabled async => (await _bluetooth.isEnabled) ?? false;

  Future<bool> ensureEnabled() async {
    // Try classic first
    final enabledClassic = await isEnabled;
    // BLE state (cannot programmatically enable on Android >= 13)
    final isBleOn = await ble.FlutterBluePlus.adapterState.first.then((s) => s == ble.BluetoothAdapterState.on);
    if (enabledClassic || isBleOn) return true;
    final res = await _bluetooth.requestEnable();
    return (res ?? false) || isBleOn;
  }

  List<int> _getMode01Data(List<String> hex, String pid, int needed) {
    for (int i = 0; i + 1 < hex.length; i++) {
      if (hex[i] == '41' && hex[i + 1] == pid.toUpperCase()) {
        final out = <int>[];
        for (int j = 0; j < needed && (i + 2 + j) < hex.length; j++) {
          out.add(_parseHexByte(hex[i + 2 + j]));
        }
        return out;
      }
    }
    return const [];
  }

  Future<void> _drainInput(Duration forDuration) async {
    final sw = Stopwatch()..start();
    StreamSubscription? sub;
    void cancel() {
      try { sub?.cancel(); } catch (_) {}
    }
    if (_connection != null && _connection!.isConnected) {
      final src = _classicInput ?? _connection!.input!.asBroadcastStream();
      sub = src.listen((_) {});
    } else if (_bleNotify != null) {
      final src = _bleInput ?? _bleNotify!.onValueReceived.asBroadcastStream();
      sub = src.listen((_) {});
    } else {
      return;
    }
    while (sw.elapsed < forDuration) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    cancel();
  }

  Stream<BluetoothState> onStateChanged() => _bluetooth.onStateChanged();

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return _bluetooth.getBondedDevices();
  }

  /// Scan for BLE devices for a short period and return name/id pairs
  Future<List<Map<String, String>>> scanBle({Duration timeout = const Duration(seconds: 4)}) async {
    final results = <Map<String, String>>[];
    final seen = <String>{};
    await ble.FlutterBluePlus.startScan(timeout: timeout);
    final subs = ble.FlutterBluePlus.scanResults.listen((scanResults) {
      for (final r in scanResults) {
        final d = r.device;
        final id = d.remoteId.str;
        if (seen.contains(id)) continue;
        // Prefer platformName, then advertised localName, then advName
        final localName = r.advertisementData.localName;
        final advName = d.advName;
        final name = d.platformName.isNotEmpty
            ? d.platformName
            : (localName.isNotEmpty
                ? localName
                : (advName.isNotEmpty ? advName : ''));
        seen.add(id);
        results.add({'name': name.isNotEmpty ? name : id, 'id': id});
      }
    });
    await Future.delayed(timeout);
    await subs.cancel();
    await ble.FlutterBluePlus.stopScan();
    // de-dup already ensured by seen
    return results;
  }

  // Ajouter retry logic
  Future<void> connect(String target, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        await _connectInternal(target);
        return;
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _connectInternal(String target) async {
    if (target.startsWith('ble:')) {
      await _connectBle(target.substring(4));
    } else if (target.startsWith('classic:')) {
      await _connectClassic(target.substring(8));
    } else {
      // backward compatibility: assume classic MAC
      await _connectClassic(target);
    }
    await _initElm327();
  }

  Future<void> _initElm327() async {
    // Reset and basic config; be generous with timeouts
    try {
      // Some adapters spew garbage right after connect; give them a brief moment
      await Future.delayed(const Duration(milliseconds: 300));
      // Drain any pending bytes to start clean
      await _drainInput(const Duration(milliseconds: 150));
      await _request('ATZ', timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 500));
      // Some clones need an extra reset
      await _request('ATZ', timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 300));
      await _request('ATE0', timeout: const Duration(seconds: 3));
      await _request('ATL0', timeout: const Duration(seconds: 3));
      await _request('ATH0', timeout: const Duration(seconds: 3));
      await _request('ATS0', timeout: const Duration(seconds: 3));
      await _request('ATAT1', timeout: const Duration(seconds: 3)); // adaptive timing on
      await _request('ATSTFF', timeout: const Duration(seconds: 3)); // max timeout
      await _request('ATSP0', timeout: const Duration(seconds: 4)); // auto protocol
      // Identify adapter (optional but useful)
      await identifyAdapter();
    } catch (e) {
      throw StateError('Initialisation ELM327 échouée: $e');
    }
  }

  Future<String> identifyAdapter() async {
    final resp = await _request('ATI', timeout: const Duration(seconds: 3));
    return resp.trim();
  }

  /// Quick ECU handshake: query supported PIDs (Mode 01 PID 00). Returns true if a valid reply is received.
  // If auto-protocol does not work, probe common protocols.
  Future<bool> handshakeEcu() async {
    // First try with current settings (likely after ATSP0)
    if (await _probeHeadersAndHandshake()) {
      // Use functional addressing for subsequent reads
      try { await _setHeader('7DF'); } catch (_) {}
      return true;
    }
    // Probe common protocols (CAN first), then ISO/KWP
    const protocols = ['6', '7', '8', '9', '1', '2', '3', '0'];
    for (final p in protocols) {
      try {
        // ignore: avoid_print
        print('>>> ELM: try protocol ATSP$p');
        await _setProtocol(p);
        if (await _probeHeadersAndHandshake()) {
          try { await _setHeader('7DF'); } catch (_) {}
          return true;
        }
      } catch (e) {
        // ignore: avoid_print
        print('>>> ELM: protocol $p failed: $e');
      }
    }
    return false;
  }

  Future<void> _setProtocol(String code) async {
    // Try "try protocol" first (keeps auto as fallback on some ELMs), then force set
    try {
      await _request('ATTP$code', timeout: const Duration(seconds: 4));
    } catch (_) {}
    await _request('ATSP$code', timeout: const Duration(seconds: 4));
    // Re-apply adaptive timing and long timeout to be safe
    await _request('ATAT1', timeout: const Duration(seconds: 3));
    await _request('ATSTFF', timeout: const Duration(seconds: 3));
    // Ensure functional OBD-II addressing is active (broadcast 7DF)
    await _request('ATCAF1', timeout: const Duration(seconds: 3));
    try {
      await _request('ATSH7DF', timeout: const Duration(seconds: 3));
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 150));
    // Log active protocol
    try {
      final dpn = await _request('ATDPN', timeout: const Duration(seconds: 3));
      final dp = await _request('ATDP', timeout: const Duration(seconds: 3));
      // ignore: avoid_print
      print('>>> ELM: active protocol: ${dpn.replaceAll('\r', ' ').replaceAll('\n', ' ').trim()} | ${dp.replaceAll('\r', ' ').replaceAll('\n', ' ').trim()}');
    } catch (_) {}
  }

  Future<bool> _handshakeOnce() async {
    String resp = await _request('0100', timeout: const Duration(seconds: 12));
    // ignore: avoid_print
    print('>>> ELM: 0100 resp: ${resp.replaceAll('\r', ' ').replaceAll('\n', ' ').trim()}');
    if (_validateResponse(resp)) return true;
    await Future.delayed(const Duration(milliseconds: 300));
    resp = await _request('0100', timeout: const Duration(seconds: 12));
    // ignore: avoid_print
    print('>>> ELM: 0100 retry resp: ${resp.replaceAll('\r', ' ').replaceAll('\n', ' ').trim()}');
    return _validateResponse(resp);
  }

  Future<bool> _probeHeadersAndHandshake() async {
    // Try functional first, then common CAN ECU addresses
    const headers = ['7DF', '7E0', '7E1', '7E2', '7E8', '7E9'];
    for (final h in headers) {
      try {
        await _setHeader(h);
        if (await _handshakeOnce()) return true;
      } catch (e) {
        // ignore: avoid_print
        print('>>> ELM: header $h failed: $e');
      }
    }
    return false;
  }

  Future<void> _setHeader(String hex) async {
    await _request('ATSH$hex', timeout: const Duration(seconds: 3));
    await Future.delayed(const Duration(milliseconds: 100));
  }

  bool _validateResponse(String resp) {
    final hex = _extractHex(resp);
    if (hex.length < 2) return false;
    // NO DATA early exit
    for (int i = 0; i + 1 < hex.length; i++) {
      if (hex[i] == 'NO' && hex[i + 1] == 'DATA') return false;
    }
    for (int i = 0; i + 1 < hex.length; i++) {
      if (hex[i] == '41' && hex[i + 1] == '00') return true;
    }
    return false;
  }

  Future<void> _connectClassic(String address) async {
    if (_connection != null && _connection!.isConnected) return;
    _connection = await BluetoothConnection.toAddress(address);
    // Prepare broadcast input stream so we can listen multiple times
    _classicInput = _connection!.input!.asBroadcastStream();
  }

  static final _uuidNusService = ble.Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  static final _uuidNusWrite = ble.Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
  static final _uuidNusNotify = ble.Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
  static final _uuidHmxService = ble.Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
  static final _uuidHmxChar = ble.Guid("0000FFE1-0000-1000-8000-00805F9B34FB");

  Future<void> _connectBle(String deviceId) async {
    // find device in current scan cache, else create from id
    final dev = ble.BluetoothDevice.fromId(deviceId);
    _bleDevice = dev;
    await dev.connect(timeout: const Duration(seconds: 8)).onError((e, _) async {
      // ignore if already connected
    });
    final services = await dev.discoverServices();
    ble.BluetoothCharacteristic? write;
    ble.BluetoothCharacteristic? notify;
    for (final s in services) {
      if (s.uuid == _uuidNusService) {
        for (final c in s.characteristics) {
          if (c.uuid == _uuidNusWrite) write = c;
          if (c.uuid == _uuidNusNotify) notify = c;
        }
      } else if (s.uuid == _uuidHmxService) {
        for (final c in s.characteristics) {
          if (c.uuid == _uuidHmxChar) {
            write = c;
            notify = c; // HM-10 uses same char for write/notify
          }
        }
      }
    }
    if (write == null || notify == null) {
      await dev.disconnect();
      throw StateError('Caractéristiques BLE UART introuvables');
    }
    _bleWrite = write;
    _bleNotify = notify;
    await _bleNotify!.setNotifyValue(true);
    // Prepare broadcast input stream for BLE notifications
    _bleInput = _bleNotify!.onValueReceived.asBroadcastStream();
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    _classicInput = null;
    if (_bleDevice != null) {
      try {
        await _bleDevice!.disconnect();
      } catch (_) {}
    }
    _bleDevice = null;
    _bleWrite = null;
    _bleNotify = null;
    _bleInput = null;
  }

  bool get isConnected => (_connection?.isConnected ?? false) || (_bleDevice != null && _bleWrite != null && _bleNotify != null);

  Future<void> _write(String cmd) async {
    final data = utf8.encode('$cmd\r');
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(data);
      await _connection!.output.allSent;
      return;
    }
    if (_bleWrite != null) {
      await _bleWrite!.write(data, withoutResponse: true);
      return;
    }
    throw StateError('Bluetooth not connected');
  }

  Future<String> _request(String cmd, {Duration timeout = const Duration(seconds: 4)}) async {
    // Drain any residual bytes from previous commands
    await _drainInput(const Duration(milliseconds: 40));
    // Slightly longer gap to avoid overrunning slow ECUs/adapters
    await Future.delayed(const Duration(milliseconds: 120));
    // ignore: avoid_print
    print('<<< $cmd');
    await _write(cmd);

    final completer = Completer<String>();
    final buffer = StringBuffer();

    StreamSubscription? sub;
    if (_connection != null && _connection!.isConnected) {
      final src = _classicInput ?? _connection!.input!.asBroadcastStream();
      sub = src.listen((event) {
        // Filter out NUL bytes and decode defensively
        final sanitized = event.where((b) => b != 0).toList();
        String chunk;
        try {
          chunk = utf8.decode(sanitized, allowMalformed: true);
        } catch (_) {
          chunk = String.fromCharCodes(sanitized.map((b) => b < 128 ? b : 0x3F)); // replace non-ascii with '?'
        }
        buffer.write(chunk);
        if (buffer.toString().contains('>')) {
          sub?.cancel();
          final resp = buffer.toString();
          // ignore: avoid_print
          print('>>> $cmd: ${resp.replaceAll('\r', ' ').replaceAll('\n', ' ').trim()}');
          completer.complete(resp);
        }
      });
    } else if (_bleNotify != null) {
      final src = _bleInput ?? _bleNotify!.onValueReceived.asBroadcastStream();
      sub = src.listen((event) {
        final sanitized = event.where((b) => b != 0).toList();
        String chunk;
        try {
          chunk = utf8.decode(sanitized, allowMalformed: true);
        } catch (_) {
          chunk = String.fromCharCodes(sanitized.map((b) => b < 128 ? b : 0x3F));
        }
        buffer.write(chunk);
        if (buffer.toString().contains('>')) {
          sub?.cancel();
          completer.complete(buffer.toString());
        }
      });
      // Ensure notifications are enabled
      await _bleNotify!.setNotifyValue(true);
    } else {
      throw StateError('Bluetooth not connected');
    }

    return completer.future.timeout(timeout, onTimeout: () {
      sub?.cancel();
      return buffer.toString();
    });
  }

  // Helpers to parse OBD-II PIDs
  static int _parseHexByte(String s) => int.parse(s, radix: 16);

  Future<int?> readRpm() async {
    final resp = await _request('010C');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '0C', 2);
    if (data.length == 2) {
      final A = data[0];
      final B = data[1];
      return (((A * 256) + B) ~/ 4).clamp(0, 20000);
    }
    return null;
  }

  Future<double?> readSpeedKmh() async {
    final resp = await _request('010D');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '0D', 1);
    if (data.length == 1) return data[0].toDouble();
    return null;
  }

  Future<double?> readEngineTempC() async {
    final resp = await _request('0105');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '05', 1);
    if (data.length == 1) return (data[0] - 40).toDouble();
    return null;
  }

  Future<double?> readEngineLoad0104() async {
    final resp = await _request('0104');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '04', 1);
    if (data.length == 1) return (100.0 * data[0]) / 255.0;
    return null;
  }

  Future<double?> readFuelPressure010A() async {
    final resp = await _request('010A');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '0A', 1);
    if (data.length == 1) return data[0] * 3.0; // kPa
    return null;
  }

  Future<double?> readMAP010B() async {
    final resp = await _request('010B');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '0B', 1);
    if (data.length == 1) return data[0].toDouble(); // kPa
    return null;
  }

  Future<double?> readIAT010F() async {
    final resp = await _request('010F');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '0F', 1);
    if (data.length == 1) return (data[0] - 40).toDouble();
    return null;
  }

  Future<double?> readMAF0110() async {
    final resp = await _request('0110');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '10', 2);
    if (data.length == 2) return ((data[0] * 256) + data[1]) / 100.0; // g/s
    return null;
  }

  Future<double?> readTPS0111() async {
    final resp = await _request('0111');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '11', 1);
    if (data.length == 1) return (100.0 * data[0]) / 255.0; // %
    return null;
  }

  Future<int?> readRunTime011F() async {
    final resp = await _request('011F');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '1F', 2);
    if (data.length == 2) return (data[0] * 256) + data[1]; // seconds
    return null;
  }

  Future<int?> readDistanceSinceDtcClear0131() async {
    final resp = await _request('0131');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '31', 2);
    if (data.length == 2) return (data[0] * 256) + data[1]; // km
    return null;
  }

  Future<String?> readFuelType0151() async {
    final resp = await _request('0151');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '51', 1);
    if (data.length == 1) {
      final A = data[0];
      switch (A) {
        case 0x01:
          return 'Essence';
        case 0x02:
          return 'Méthanol';
        case 0x03:
          return 'Éthanol';
        case 0x04:
          return 'Diesel';
        default:
          return 'Inconnu($A)';
      }
    }
    return null;
  }

  Future<double?> readOilTemp015C() async {
    final resp = await _request('015C');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '5C', 1);
    if (data.length == 1) return (data[0] - 40).toDouble();
    return null;
  }

  Future<double?> readFuelRate015E() async {
    final resp = await _request('015E');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '5E', 2);
    if (data.length == 2) return ((data[0] * 256) + data[1]) / 20.0; // L/h 
    return null;
  }

  Future<double?> readFuelTemp015F() async {
    final resp = await _request('015F');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '5F', 1);
    if (data.length == 1) return (data[0] - 40).toDouble();
    return null;
  }

  /// Total odometer (km) — Mode 01 PID A6 (if supported). Returns null if not available.
  Future<double?> readOdometer01A6() async {
    final resp = await _request('01A6');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, 'A6', 4);
    if (data.length == 4) {
      final value = (data[0] << 24) + (data[1] << 16) + (data[2] << 8) + data[3];
      return value.toDouble();
    }
    return null;
  }

  Future<int?> readFuelLevelPercent() async {
    final resp = await _request('012F');
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '2F', 1);
    if (data.length == 1) return ((100 * data[0]) / 255).round();
    return null;
  }

  Future<List<String>> readDtcCodes() async {
    // Mode 03 returns stored DTCs. Parsing simplified.
    final resp = await _request('03');
    final hex = _extractHex(resp);
    if (hex.length <= 2) return [];
    // Very basic decode: group bytes by 2 after first 2 bytes
    final codeBytes = hex.skip(2).toList();
    final codes = <String>[];
    for (var i = 0; i + 1 < codeBytes.length; i += 2) {
      codes.add('${codeBytes[i]}${codeBytes[i + 1]}');
    }
    return codes;
  }

  List<String> _extractHex(String response) {
    // Normalize and split, then expand pure hex runs into byte pairs
    final cleaned = response
        .replaceAll('>', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(':', ' ')
        .trim()
        .toUpperCase();
    final parts = cleaned.split(RegExp(r'\s+'));
    final out = <String>[];
    final hexRe = RegExp(r'^[0-9A-F]+$');
    for (final p in parts) {
      if (p.isEmpty) continue;
      // ignore common non-hex noise
      if (p.startsWith('SEARCHING') || p == 'STOPPED') continue;
      if (p == 'CAN' || p == 'ERROR' || p == 'BUS' || p == 'INIT' || p == 'NO' || p == 'DATA') {
        // keep 'NO' 'DATA' as separate tokens for validation only
        if (p == 'NO' || p == 'DATA') out.add(p);
        continue;
      }
      if (hexRe.hasMatch(p)) {
        // expand into byte pairs
        for (int i = 0; i + 1 < p.length; i += 2) {
          out.add(p.substring(i, i + 2));
        }
      }
    }
    return out;
  }

  Future<void> clearDTC() async {
    if (!isConnected) throw StateError('Bluetooth not connected');
    await _request('04');
  }

  /// Query Mode 01 PID 00 and compute supported PIDs (01-20)
  Future<Set<String>> getSupportedPids() async {
    final resp = await _request('0100', timeout: const Duration(seconds: 6));
    final hex = _extractHex(resp);
    final data = _getMode01Data(hex, '00', 4);
    final out = <String>{};
    if (data.length == 4) {
      int mask = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      for (int i = 0; i < 32; i++) {
        if ((mask & (1 << (31 - i))) != 0) {
          final pid = i + 1; // PIDs 01..20
          out.add(pid.toRadixString(16).toUpperCase().padLeft(2, '0'));
        }
      }
    }
    return out;
  }
}
