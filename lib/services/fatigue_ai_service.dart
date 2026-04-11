import 'package:flutter/foundation.dart';
import 'fleet_ai_engine.dart';

/// ════════════════════════════════════════════════════════════════
/// [LEGACY STUB] FatigueAiService
/// ════════════════════════════════════════════════════════════════
///
/// Ce service est conservé pour la rétrocompatibilité uniquement.
/// La logique IA a été entièrement migrée vers [FleetAiEngine].
///
/// ⚠️ N'ajoutez pas de nouvelle logique ici.
///   → Utilisez directement FleetAiEngine().analyzeComplete(...)
/// ════════════════════════════════════════════════════════════════

class FatigueAiService {
  static final FatigueAiService _instance = FatigueAiService._internal();
  factory FatigueAiService() => _instance;
  FatigueAiService._internal();

  /// Initialisation (délègue à FleetAiEngine)
  Future<void> initialize() async {
    await FleetAiEngine().initialize();
    debugPrint('🧠 FatigueAiService → délégation à FleetAiEngine v2 (Dart natif)');
  }

  /// Calcule le risque de fatigue (0.0 → 1.0)
  /// Délègue au moteur multi-critères FleetAiEngine.
  Future<double> predictFatigueRisk({
    required double durationHours,
    required double hourOfDay,
    required double avgRpm,
    required int brakeCount,
    required int overspeedCount,
  }) async {
    final result = FleetAiEngine().analyzeComplete(
      durationHours: durationHours,
      hourOfDay: hourOfDay,
      rpm: avgRpm.toInt(),
      speed: 0,
      brakeCount: brakeCount,
      overspeedCount: overspeedCount,
      // Valeurs inconnues → valeurs sûres par défaut
      temperature: 85,
      fuelPct: 50,
      oilPressure: 3.0,
      consoL100: 0,
      dtcCount: 0,
      milOn: false,
      batteryVoltage: 24.0,
      engineLoadPct: 0,
      oilTempC: 90,
      ambientTempC: 25,
      camion: '',
    );
    return result.fatigueRisk;
  }
}
