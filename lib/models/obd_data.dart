
class OBDData {
  final int rpm;
  final double engineTempC;
  final double speedKmh;
  final double oilPressureBar;
  final int fuelLevelPercent;
  final double instantConsumptionLPer100;
  final double distanceKm;
  final List<String> dtcCodes;
  final bool engineOk;
  final DateTime timestamp;
  // Extended optional metrics
  final double? odometerKm; // 01 A6 total odometer
  final double? engineLoadPct; // 0104
  final double? fuelPressureKpa; // 010A
  final double? mapKpa; // 010B
  final double? iatC; // 010F
  final double? tpsPct; // 0111
  final int? runTimeSec; // 011F
  final int? distanceSinceDtcKm; // 0131
  final String? fuelType; // 0151
  final double? oilTempC; // 015C
  final double? fuelRateLh; // 015E
  final double? fuelTempC; // 015F
  final double? mafGps; // 0110

  const OBDData({
    required this.rpm,
    required this.engineTempC,
    required this.speedKmh,
    required this.oilPressureBar,
    required this.fuelLevelPercent,
    required this.instantConsumptionLPer100,
    required this.distanceKm,
    required this.dtcCodes,
    required this.engineOk,
    required this.timestamp,
    this.odometerKm,
    this.engineLoadPct,
    this.fuelPressureKpa,
    this.mapKpa,
    this.iatC,
    this.tpsPct,
    this.runTimeSec,
    this.distanceSinceDtcKm,
    this.fuelType,
    this.oilTempC,
    this.fuelRateLh,
    this.fuelTempC,
    this.mafGps,
  });

  factory OBDData.initial() => OBDData(
        rpm: 0,
        engineTempC: 0,
        speedKmh: 0,
        oilPressureBar: 0,
        fuelLevelPercent: 0,
        instantConsumptionLPer100: 0,
        distanceKm: 0,
        dtcCodes: const [],
        engineOk: true,
        timestamp: DateTime.now(),
      );

  OBDData copyWith({
    int? rpm,
    double? engineTempC,
    double? speedKmh,
    double? oilPressureBar,
    int? fuelLevelPercent,
    double? instantConsumptionLPer100,
    double? distanceKm,
    List<String>? dtcCodes,
    bool? engineOk,
    DateTime? timestamp,
    double? odometerKm,
    double? engineLoadPct,
    double? fuelPressureKpa,
    double? mapKpa,
    double? iatC,
    double? tpsPct,
    int? runTimeSec,
    int? distanceSinceDtcKm,
    String? fuelType,
    double? oilTempC,
    double? fuelRateLh,
    double? fuelTempC,
    double? mafGps,
  }) {
    return OBDData(
      rpm: rpm ?? this.rpm,
      engineTempC: engineTempC ?? this.engineTempC,
      speedKmh: speedKmh ?? this.speedKmh,
      oilPressureBar: oilPressureBar ?? this.oilPressureBar,
      fuelLevelPercent: fuelLevelPercent ?? this.fuelLevelPercent,
      instantConsumptionLPer100:
          instantConsumptionLPer100 ?? this.instantConsumptionLPer100,
      distanceKm: distanceKm ?? this.distanceKm,
      dtcCodes: dtcCodes ?? this.dtcCodes,
      engineOk: engineOk ?? this.engineOk,
      timestamp: timestamp ?? this.timestamp,
      odometerKm: odometerKm ?? this.odometerKm,
      engineLoadPct: engineLoadPct ?? this.engineLoadPct,
      fuelPressureKpa: fuelPressureKpa ?? this.fuelPressureKpa,
      mapKpa: mapKpa ?? this.mapKpa,
      iatC: iatC ?? this.iatC,
      tpsPct: tpsPct ?? this.tpsPct,
      runTimeSec: runTimeSec ?? this.runTimeSec,
      distanceSinceDtcKm: distanceSinceDtcKm ?? this.distanceSinceDtcKm,
      fuelType: fuelType ?? this.fuelType,
      oilTempC: oilTempC ?? this.oilTempC,
      fuelRateLh: fuelRateLh ?? this.fuelRateLh,
      fuelTempC: fuelTempC ?? this.fuelTempC,
      mafGps: mafGps ?? this.mafGps,
    );
  }

  Map<String, dynamic> toJson({required String camionId}) => {
        'camion': camionId,
        'rpm': rpm,
        'temperature': engineTempC.round(),
        'vitesse': speedKmh.round(),
        'carburant': fuelLevelPercent,
        'pression_huile_bar': oilPressureBar,
        'conso_l_100': instantConsumptionLPer100,
        'distance_km': distanceKm,
        'dtc': dtcCodes,
        'status_ok': engineOk,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (odometerKm != null) 'odometer_km': odometerKm,
        if (engineLoadPct != null) 'engine_load_pct': engineLoadPct,
        if (fuelPressureKpa != null) 'fuel_pressure_kpa': fuelPressureKpa,
        if (mapKpa != null) 'map_kpa': mapKpa,
        if (iatC != null) 'iat_c': iatC,
        if (tpsPct != null) 'tps_pct': tpsPct,
        if (runTimeSec != null) 'run_time_sec': runTimeSec,
        if (distanceSinceDtcKm != null) 'dist_since_dtc_km': distanceSinceDtcKm,
        if (fuelType != null) 'fuel_type': fuelType,
        if (oilTempC != null) 'oil_temp_c': oilTempC,
        if (fuelRateLh != null) 'fuel_rate_lh': fuelRateLh,
        if (fuelTempC != null) 'fuel_temp_c': fuelTempC,
        if (mafGps != null) 'maf_gps': mafGps,
      };
}
