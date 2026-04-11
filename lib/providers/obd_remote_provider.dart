import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Data Model (mirrors Supabase obd_data table) ───

class OBDRemoteData {
  final int rpm;
  final int temperature;
  final int vitesse;
  final int carburant;
  final double pressionHuileBar;
  final double consoL100;
  final double distanceKm;
  final bool statusOk;
  final double? engineLoadPct;
  final double? mafGps;
  final double? batteryVoltage;
  final double? tpsPct;
  final double? fuelRateLh;
  final double fuelConsumedTotalL;
  final double? fuelPressureKpa;
  final double? fuelRailKpa;
  final double? fuelTempC;
  final double? oilTempC;
  final double? ambientTempC;
  final double? baroKpa;
  final double? mapKpa;
  final double? iatC;
  final double? pedalPct;
  final int? runTimeSec;
  final int? distSinceDtcKm;
  final String? fuelType;
  final bool milOn;
  final int dtcCount;
  final String? dtcCodes;
  final String? dtcPending;
  final String camion;
  final DateTime createdAt;

  // ── Champs spécifiques Poids Lourds (J1939) ──
  final double? turboPressureKpa;  // Pression turbo
  final double? exhaustTempC;      // Température échappement
  final int? adBlueLevelPct;       // Niveau AdBlue/DEF
  final int? gearCurrent;          // Rapport de boîte (-1=R, 0=N, 1-16)
  final double? torquePct;         // Couple moteur (%)
  final double? odometerKm;        // Odomètre total (km)
  final double? retarderPct;       // Retarder / frein moteur (%)
  final double? coolantLevelPct;   // Niveau liquide refroidissement
  final double? fuelTotalL;        // Consommation totale depuis usine
  final String? protocol;          // Protocole détecté (J1939 / OBD-II)

  const OBDRemoteData({
    required this.rpm,
    required this.temperature,
    required this.vitesse,
    required this.carburant,
    required this.pressionHuileBar,
    required this.consoL100,
    required this.distanceKm,
    required this.statusOk,
    this.engineLoadPct,
    this.mafGps,
    this.batteryVoltage,
    this.tpsPct,
    this.fuelRateLh,
    this.fuelConsumedTotalL = 0,
    this.fuelPressureKpa,
    this.fuelRailKpa,
    this.fuelTempC,
    this.oilTempC,
    this.ambientTempC,
    this.baroKpa,
    this.mapKpa,
    this.iatC,
    this.pedalPct,
    this.runTimeSec,
    this.distSinceDtcKm,
    this.fuelType,
    this.milOn = false,
    this.dtcCount = 0,
    this.dtcCodes,
    this.dtcPending,
    required this.camion,
    required this.createdAt,
    // Poids lourds
    this.turboPressureKpa,
    this.exhaustTempC,
    this.adBlueLevelPct,
    this.gearCurrent,
    this.torquePct,
    this.odometerKm,
    this.retarderPct,
    this.coolantLevelPct,
    this.fuelTotalL,
    this.protocol,
  });

  factory OBDRemoteData.fromJson(Map<String, dynamic> json) {
    return OBDRemoteData(
      rpm: (json['rpm'] as num?)?.toInt() ?? 0,
      temperature: (json['temperature'] as num?)?.toInt() ?? 0,
      vitesse: (json['vitesse'] as num?)?.toInt() ?? 0,
      carburant: (json['carburant'] as num?)?.toInt() ?? 0,
      pressionHuileBar: (json['pression_huile_bar'] as num?)?.toDouble() ?? 0,
      consoL100: (json['conso_l_100'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      statusOk: json['status_ok'] as bool? ?? true,
      engineLoadPct: (json['engine_load_pct'] as num?)?.toDouble(),
      mafGps: (json['maf_gps'] as num?)?.toDouble(),
      batteryVoltage: (json['battery_voltage'] as num?)?.toDouble(),
      tpsPct: (json['tps_pct'] as num?)?.toDouble(),
      fuelRateLh: (json['fuel_rate_lh'] as num?)?.toDouble(),
      fuelConsumedTotalL: (json['fuel_consumed_total_l'] as num?)?.toDouble() ?? 0,
      fuelPressureKpa: (json['fuel_pressure_kpa'] as num?)?.toDouble(),
      fuelRailKpa: (json['fuel_rail_kpa'] as num?)?.toDouble(),
      fuelTempC: (json['fuel_temp_c'] as num?)?.toDouble(),
      oilTempC: (json['oil_temp_c'] as num?)?.toDouble(),
      ambientTempC: (json['ambient_temp_c'] as num?)?.toDouble(),
      baroKpa: (json['baro_kpa'] as num?)?.toDouble(),
      mapKpa: (json['map_kpa'] as num?)?.toDouble(),
      iatC: (json['iat_c'] as num?)?.toDouble(),
      pedalPct: (json['pedal_pct'] as num?)?.toDouble(),
      runTimeSec: (json['run_time_sec'] as num?)?.toInt(),
      distSinceDtcKm: (json['dist_since_dtc_km'] as num?)?.toInt(),
      fuelType: json['fuel_type'] as String?,
      milOn: json['mil_on'] as bool? ?? false,
      dtcCount: (json['dtc_count'] as num?)?.toInt() ?? 0,
      dtcCodes: json['dtc_codes'] as String?,
      dtcPending: json['dtc_pending'] as String?,
      camion: json['camion'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      // Poids lourds (J1939)
      turboPressureKpa: (json['turbo_pressure_kpa'] as num?)?.toDouble(),
      exhaustTempC: (json['exhaust_temp_c'] as num?)?.toDouble(),
      adBlueLevelPct: (json['adblue_level_pct'] as num?)?.toInt(),
      gearCurrent: (json['gear_current'] as num?)?.toInt(),
      torquePct: (json['torque_pct'] as num?)?.toDouble(),
      odometerKm: (json['odometer_km'] as num?)?.toDouble(),
      retarderPct: (json['retarder_pct'] as num?)?.toDouble(),
      coolantLevelPct: (json['coolant_level_pct'] as num?)?.toDouble(),
      fuelTotalL: (json['fuel_total_l'] as num?)?.toDouble(),
      protocol: json['protocol'] as String?,
    );
  }

  static OBDRemoteData empty() => OBDRemoteData(
        rpm: 0,
        temperature: 0,
        vitesse: 0,
        carburant: 0,
        pressionHuileBar: 0,
        consoL100: 0,
        distanceKm: 0,
        statusOk: true,
        camion: '',
        createdAt: DateTime.now(),
      );
}

// ─── State ───

class OBDRemoteState {
  final OBDRemoteData data;
  final List<OBDRemoteData> history; // last N entries for charts
  final bool isLoading;
  final bool isLive;
  final String? error;
  final DateTime? lastUpdate;
  final DateTime lastPolledAt; // changes every poll to force UI rebuild

  OBDRemoteState({
    required this.data,
    this.history = const [],
    this.isLoading = false,
    this.isLive = false,
    this.error,
    this.lastUpdate,
    DateTime? lastPolledAt,
  }) : lastPolledAt = lastPolledAt ?? DateTime.now();

  OBDRemoteState copyWith({
    OBDRemoteData? data,
    List<OBDRemoteData>? history,
    bool? isLoading,
    bool? isLive,
    String? error,
    DateTime? lastUpdate,
    DateTime? lastPolledAt,
  }) {
    return OBDRemoteState(
      data: data ?? this.data,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isLive: isLive ?? this.isLive,
      error: error,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      lastPolledAt: lastPolledAt ?? this.lastPolledAt,
    );
  }
}

// ─── Provider ───

class OBDRemoteNotifier extends StateNotifier<OBDRemoteState> {
  final String camionId;
  final String plate;
  Timer? _pollTimer;
  RealtimeChannel? _channel;
  String? _resolvedCamionKey; // The actual 'camion' value in Supabase

  OBDRemoteNotifier(this.camionId, this.plate)
      : super(OBDRemoteState(data: OBDRemoteData.empty())) {
    _startListening();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _startListening() async {
    state = state.copyWith(isLoading: true);

    // 1. Resolve which 'camion' value is in the DB
    await _resolveAndFetch();
    await _fetchHistory();

    // 2. Subscribe to ALL inserts on obd_data (no filter — avoids mismatch)
    _channel = _supabase
        .channel('obd_realtime_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'obd_data',
          callback: (payload) {
            final newData = OBDRemoteData.fromJson(payload.newRecord);
            // Accept if camion matches any known format, or if we have no resolved key yet
            if (_resolvedCamionKey == null ||
                newData.camion == _resolvedCamionKey ||
                newData.camion == camionId ||
                newData.camion == plate ||
                newData.camion.toLowerCase().replaceAll(' ', '_') == camionId) {
              final updatedHistory = [...state.history, newData];
              if (updatedHistory.length > 60) {
                updatedHistory.removeRange(0, updatedHistory.length - 60);
              }
              state = state.copyWith(
                data: newData,
                history: updatedHistory,
                isLive: true,
                lastUpdate: DateTime.now(),
              );
            }
          },
        )
        .subscribe();

    // 3. Fallback polling every 5s
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _resolveAndFetch();
    });

    state = state.copyWith(isLoading: false, isLive: true);
  }

  /// Try multiple query strategies to find OBD data for this truck
  Future<void> _resolveAndFetch() async {
    try {
      Map<String, dynamic>? response;

      // Strategy 1: try with exact camionId (e.g. "161_tun_1284")
      response = await _supabase
          .from('obd_data')
          .select()
          .eq('camion', camionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Strategy 2: try with plate (e.g. "161 TUN 1284")
      if (response == null && plate.isNotEmpty) {
        response = await _supabase
            .from('obd_data')
            .select()
            .eq('camion', plate)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      // Strategy 3: try with plate uppercase (e.g. "161 TUN 1284")
      if (response == null && plate.isNotEmpty) {
        response = await _supabase
            .from('obd_data')
            .select()
            .eq('camion', plate.toUpperCase())
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      // Strategy 4: just get the most recent entry from ANY camion
      if (response == null) {
        response = await _supabase
            .from('obd_data')
            .select()
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (response != null) {
        final data = OBDRemoteData.fromJson(response);
        _resolvedCamionKey = data.camion;
        
        // Only update lastUpdate if data is actually NEW (different created_at)
        final isNew = state.data.createdAt != data.createdAt;
        state = state.copyWith(
          data: data,
          lastUpdate: isNew ? data.createdAt : state.lastUpdate,
          isLive: isNew,
          error: null,
          lastPolledAt: DateTime.now(), // force UI rebuild
        );
      } else {
        // No data at all — still force rebuild
        state = state.copyWith(lastPolledAt: DateTime.now(), isLive: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLive: false, lastPolledAt: DateTime.now());
    }
  }

  Future<void> _fetchHistory() async {
    try {
      List<dynamic> response;

      if (_resolvedCamionKey != null && _resolvedCamionKey!.isNotEmpty) {
        response = await _supabase
            .from('obd_data')
            .select()
            .eq('camion', _resolvedCamionKey!)
            .order('created_at', ascending: false)
            .limit(60);
      } else {
        // Fallback: get latest 60 entries regardless of camion
        response = await _supabase
            .from('obd_data')
            .select()
            .order('created_at', ascending: false)
            .limit(60);
      }

      final list = response
          .map((e) => OBDRemoteData.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();

      state = state.copyWith(history: list);
    } catch (e) {
      // History is non-critical, ignore errors
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _resolveAndFetch();
    await _fetchHistory();
    state = state.copyWith(isLoading: false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}

// Family provider — keyed by "camionId|plate"
final obdRemoteProvider = StateNotifierProvider.family<OBDRemoteNotifier, OBDRemoteState, String>(
  (ref, key) {
    // Key format: "camionId|plate"
    final parts = key.split('|');
    final camionId = parts[0];
    final plate = parts.length > 1 ? parts[1] : '';
    return OBDRemoteNotifier(camionId, plate);
  },
);
