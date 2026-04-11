import 'dart:math';
import 'package:flutter/foundation.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// 🧠 FleetGuard AI Engine — Moteur d'Intelligence Artificielle Embarqué
/// ══════════════════════════════════════════════════════════════════════════════
///
/// Système de détection multi-critères avancé pour la gestion de flotte.
/// Analyse les données OBD-II en temps réel pour calculer :
///   • Score de Fatigue du Chauffeur (0% → 100%)
///   • Score de Risque Global de Conduite (0% → 100%)
///   • Score de Santé Moteur (100% → 0%)
///   • Détection du Vol de Carburant (probabilité)
///   • Indice d'Éco-conduite (0 → 100)
///
/// Architecture : Weighted Multi-Factor Scoring + Exponential Decay + Fuzzy Logic
/// Fonctionne 100% en local, hors-ligne, sans serveur.
/// ══════════════════════════════════════════════════════════════════════════════

class FleetAiEngine {
  // ─── Singleton ───
  static final FleetAiEngine _instance = FleetAiEngine._internal();
  factory FleetAiEngine() => _instance;
  FleetAiEngine._internal();

  // ─── État interne (conservé entre les appels pour l'analyse temporelle) ───
  final Map<String, _VehicleAiState> _vehicleStates = {};

  /// Initialise le moteur IA
  Future<void> initialize() async {
    debugPrint('🧠 FleetGuard AI Engine v2.0 initialisé');
    debugPrint('🧠 Mode : Multi-Criteria Weighted Scoring (Dart natif)');
    debugPrint('🧠 Modules : Fatigue | Conduite | Moteur | Carburant | Éco-score');
  }

  /// Récupère ou crée l'état IA pour un véhicule donné
  _VehicleAiState _getState(String camion) {
    return _vehicleStates.putIfAbsent(camion, () => _VehicleAiState());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. SCORE DE FATIGUE DU CHAUFFEUR (0.0 → 1.0)
  // ═══════════════════════════════════════════════════════════════════════════
  /// Algorithme avancé multi-critères inspiré de la recherche en sécurité routière.
  ///
  /// Facteurs analysés :
  ///   - Durée de conduite continue (facteur principal, réglementation EU)
  ///   - Heure de la journée (rythme circadien / chronobiologie)
  ///   - Variabilité des mouvements (micro-corrections = fatigue)
  ///   - Événements de conduite (freinages brusques, excès de vitesse)
  ///   - Température du poste de conduite (chaleur = somnolence)
  ///   - Historique d'événements accumulés
  double predictFatigueRisk({
    required double durationHours,
    required double hourOfDay,
    required double avgRpm,
    required int brakeCount,
    required int overspeedCount,
    double? coolantTempC,
    double? ambientTempC,
    double? speedVariance,
    String camion = '',
  }) {
    final state = _getState(camion);

    // ── Facteur 1 : Durée de conduite (45% du score) ──
    // Réglementation EU : max 4.5h sans pause, risque exponentiel après 3h
    double durationFactor;
    if (durationHours <= 1.0) {
      durationFactor = 0.0; // Aucun risque en dessous d'1h
    } else if (durationHours <= 2.5) {
      durationFactor = (durationHours - 1.0) / 6.0; // Montée linéaire douce
    } else if (durationHours <= 4.5) {
      durationFactor = 0.25 + pow((durationHours - 2.5) / 2.0, 1.5) * 0.35;
    } else {
      // Au-delà de 4.5h : courbe exponentielle (très dangereux)
      durationFactor = 0.6 + (1.0 - exp(-(durationHours - 4.5) / 2.0)) * 0.4;
    }

    // ── Facteur 2 : Rythme circadien (25% du score) ──
    // Le creux circadien se situe entre 2h-6h et 14h-16h
    double circadianFactor;
    if (hourOfDay >= 2 && hourOfDay <= 6) {
      // Fenêtre critique nocturne
      circadianFactor = 0.8 + 0.2 * sin((hourOfDay - 2) / 4 * pi);
    } else if (hourOfDay >= 14 && hourOfDay <= 16) {
      // Creux post-prandial (après le déjeuner)
      circadianFactor = 0.3 + 0.2 * sin((hourOfDay - 14) / 2 * pi);
    } else if (hourOfDay >= 22 || hourOfDay <= 1) {
      // Début de nuit
      circadianFactor = 0.5;
    } else {
      circadianFactor = 0.05; // Période d'éveil normal
    }

    // ── Facteur 3 : Comportement de conduite anormal (15% du score) ──
    // Des freinages brusques fréquents + excès de vitesse = signe de fatigue
    state.totalBrakes += brakeCount;
    state.totalOverspeeds += overspeedCount;
    double eventRate = (state.totalBrakes * 2.0 + state.totalOverspeeds) /
        max(durationHours * 60.0, 1.0); // Événements par minute
    double eventFactor = (1.0 - exp(-eventRate * 3)).clamp(0.0, 1.0);

    // ── Facteur 4 : Variabilité de la vitesse / RPM (10% du score) ──
    // Une conduite erratique (RPM variable) est un marqueur de micro-sommeils
    state.rpmHistory.add(avgRpm);
    if (state.rpmHistory.length > 30) state.rpmHistory.removeAt(0);
    double rpmVariance = _calculateVariance(state.rpmHistory);
    double rpmFactor = (rpmVariance / 250000.0).clamp(0.0, 1.0);

    // ── Facteur 5 : Conditions environnementales (5% du score) ──
    double envFactor = 0.0;
    if (ambientTempC != null && ambientTempC > 30) {
      envFactor += ((ambientTempC - 30) / 15.0).clamp(0.0, 0.5);
    }
    if (coolantTempC != null && coolantTempC > 95) {
      envFactor += 0.2; // Chaleur du moteur → habitacle chaud
    }

    // ── Score Final Pondéré ──
    double rawScore = (durationFactor * 0.45) +
        (circadianFactor * 0.25) +
        (eventFactor * 0.15) +
        (rpmFactor * 0.10) +
        (envFactor * 0.05);

    // Application d'un lissage exponentiel (Exponential Moving Average)
    state.lastFatigueScore =
        state.lastFatigueScore * 0.3 + rawScore * 0.7;

    final result = state.lastFatigueScore.clamp(0.0, 1.0);

    debugPrint('🧠 IA Fatigue [$camion] : '
        'Durée=${durationHours.toStringAsFixed(1)}h '
        'Heure=${hourOfDay.toStringAsFixed(1)} '
        '→ ${(result * 100).toStringAsFixed(0)}% '
        '[D:${(durationFactor * 100).toInt()}% '
        'C:${(circadianFactor * 100).toInt()}% '
        'E:${(eventFactor * 100).toInt()}% '
        'R:${(rpmFactor * 100).toInt()}%]');

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. SCORE DE RISQUE DE CONDUITE (0.0 → 1.0)
  // ═══════════════════════════════════════════════════════════════════════════
  /// Évalue le risque routier global combinant la conduite + la fatigue.
  double predictDrivingRisk({
    required int speed,
    required int rpm,
    required int brakeCount,
    required int overspeedCount,
    required double fatigueScore,
    String camion = '',
  }) {
    final state = _getState(camion);

    // Vitesse excessive (pondération non linéaire)
    double speedRisk = 0.0;
    if (speed > 90) {
      speedRisk = ((speed - 90) / 50.0).clamp(0.0, 1.0);
      speedRisk = pow(speedRisk, 0.8).toDouble(); // Courbe concave
    }

    // Sur-régime moteur
    double rpmRisk = 0.0;
    if (rpm > 3000) {
      rpmRisk = ((rpm - 3000) / 2000.0).clamp(0.0, 1.0);
    }

    // Accumulation de freinages brusques (dangereux sur la durée)
    double brakeRisk = (brakeCount / 5.0).clamp(0.0, 1.0);

    // La fatigue amplifie TOUS les risques (facteur multiplicateur)
    double fatigueAmplifier = 1.0 + fatigueScore * 1.5;

    double raw = ((speedRisk * 0.35 + rpmRisk * 0.20 + brakeRisk * 0.20 +
                fatigueScore * 0.25) *
            fatigueAmplifier)
        .clamp(0.0, 1.0);

    // Lissage
    state.lastDrivingRisk = state.lastDrivingRisk * 0.3 + raw * 0.7;
    return state.lastDrivingRisk.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. SCORE DE SANTÉ MOTEUR (1.0 = parfait → 0.0 = critique)
  // ═══════════════════════════════════════════════════════════════════════════
  double predictEngineHealth({
    required int temperature,
    required double oilPressure,
    int dtcCount = 0,
    bool milOn = false,
    double? batteryVoltage,
    double? engineLoadPct,
    double? oilTempC,
  }) {
    double health = 1.0;

    // Température du liquide de refroidissement
    if (temperature > 110) {
      health -= 0.4; // Surchauffe critique
    } else if (temperature > 100) {
      health -= 0.2;
    } else if (temperature > 95) {
      health -= 0.05;
    }

    // Pression d'huile trop basse
    if (oilPressure < 1.0) {
      health -= 0.35; // Danger critique
    } else if (oilPressure < 2.0) {
      health -= 0.15;
    }

    // Température d'huile
    if (oilTempC != null && oilTempC > 130) {
      health -= 0.2;
    }

    // Codes défaut
    if (milOn) health -= 0.2;
    health -= (dtcCount * 0.05).clamp(0.0, 0.3);

    // Batterie
    if (batteryVoltage != null) {
      if (batteryVoltage < 11.5) {
        health -= 0.15;
      } else if (batteryVoltage < 12.0) {
        health -= 0.05;
      }
    }

    // Charge moteur constamment haute
    if (engineLoadPct != null && engineLoadPct > 85) {
      health -= 0.1;
    }

    return health.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. DÉTECTION DE VOL DE CARBURANT (0.0 → 1.0)
  // ═══════════════════════════════════════════════════════════════════════════
  /// Analyse la chute de carburant pour détecter un siphonnage suspect.
  double detectFuelTheft({
    required double currentFuelPct,
    required int speed,
    required int rpm,
    String camion = '',
  }) {
    final state = _getState(camion);

    if (state.lastFuelLevel == null) {
      state.lastFuelLevel = currentFuelPct;
      state.fuelCheckTimestamp = DateTime.now();
      return 0.0;
    }

    final now = DateTime.now();
    final elapsed =
        now.difference(state.fuelCheckTimestamp ?? now).inSeconds;

    if (elapsed < 10) return state.lastFuelTheftScore; // Trop tôt pour juger

    final drop = state.lastFuelLevel! - currentFuelPct;
    final isEngineOff = rpm < 100;
    final isStationary = speed < 3;

    double suspicion = 0.0;

    if (drop > 2.0 && isStationary && isEngineOff) {
      // Chute > 2% au repos, moteur éteint → Très suspect
      suspicion = (drop / 10.0).clamp(0.3, 1.0);
    } else if (drop > 5.0 && isStationary) {
      // Chute > 5% à l'arrêt même moteur allumé
      suspicion = (drop / 15.0).clamp(0.2, 0.8);
    } else if (drop > 8.0 && elapsed < 60) {
      // Chute > 8% en moins d'1 min → anormal même en roulant
      suspicion = 0.5;
    }

    state.lastFuelLevel = currentFuelPct;
    state.fuelCheckTimestamp = now;
    state.lastFuelTheftScore =
        state.lastFuelTheftScore * 0.2 + suspicion * 0.8;

    if (state.lastFuelTheftScore > 0.3) {
      debugPrint('🧠 IA ALERTE CARBURANT [$camion] : '
          'Drop=${drop.toStringAsFixed(1)}% '
          'Suspicion=${(state.lastFuelTheftScore * 100).toStringAsFixed(0)}%');
    }

    return state.lastFuelTheftScore.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  5. INDICE D'ÉCO-CONDUITE (0 → 100, plus c'est haut = mieux)
  // ═══════════════════════════════════════════════════════════════════════════
  double calculateEcoScore({
    required int rpm,
    required int speed,
    required double consoL100,
    int brakeCount = 0,
    int overspeedCount = 0,
  }) {
    double score = 100.0;

    // Pénalité RPM élevé (conduite agressive)
    if (rpm > 2500) {
      score -= ((rpm - 2500) / 100.0).clamp(0, 25);
    }

    // Pénalité consommation excessive
    if (speed > 5) {
      // En roulant seulement
      if (consoL100 > 30) {
        score -= 20;
      } else if (consoL100 > 20) {
        score -= 10;
      } else if (consoL100 > 15) {
        score -= 5;
      }
    }

    // Pénalités d'événements
    score -= (brakeCount * 3.0).clamp(0, 15);
    score -= (overspeedCount * 2.0).clamp(0, 15);

    // Bonus vitesse optimale (60-80 km/h pour un camion)
    if (speed >= 60 && speed <= 80 && rpm < 2200) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  6. ANALYSE COMPLÈTE (retourne tous les scores en un appel)
  // ═══════════════════════════════════════════════════════════════════════════
  FleetAiResult analyzeComplete({
    required double durationHours,
    required double hourOfDay,
    required int rpm,
    required int speed,
    required int temperature,
    required int fuelPct,
    required double oilPressure,
    required double consoL100,
    int brakeCount = 0,
    int overspeedCount = 0,
    int dtcCount = 0,
    bool milOn = false,
    double? batteryVoltage,
    double? engineLoadPct,
    double? oilTempC,
    double? ambientTempC,
    String camion = '',
  }) {
    final fatigue = predictFatigueRisk(
      durationHours: durationHours,
      hourOfDay: hourOfDay,
      avgRpm: rpm.toDouble(),
      brakeCount: brakeCount,
      overspeedCount: overspeedCount,
      coolantTempC: temperature.toDouble(),
      ambientTempC: ambientTempC,
      camion: camion,
    );

    final driving = predictDrivingRisk(
      speed: speed,
      rpm: rpm,
      brakeCount: brakeCount,
      overspeedCount: overspeedCount,
      fatigueScore: fatigue,
      camion: camion,
    );

    final engine = predictEngineHealth(
      temperature: temperature,
      oilPressure: oilPressure,
      dtcCount: dtcCount,
      milOn: milOn,
      batteryVoltage: batteryVoltage,
      engineLoadPct: engineLoadPct,
      oilTempC: oilTempC,
    );

    final fuelTheft = detectFuelTheft(
      currentFuelPct: fuelPct.toDouble(),
      speed: speed,
      rpm: rpm,
      camion: camion,
    );

    final eco = calculateEcoScore(
      rpm: rpm,
      speed: speed,
      consoL100: consoL100,
      brakeCount: brakeCount,
      overspeedCount: overspeedCount,
    );

    return FleetAiResult(
      fatigueRisk: fatigue,
      drivingRisk: driving,
      engineHealth: engine,
      fuelTheftRisk: fuelTheft,
      ecoScore: eco,
      fatigueLevel: _fatigueLevel(fatigue),
      drivingLevel: _riskLevel(driving),
      engineLevel: _healthLevel(engine),
      alerts: _generateAlerts(fatigue, driving, engine, fuelTheft, camion),
    );
  }

  // ─── Utilitaires ────────────────────────────────────────────────────────

  double _calculateVariance(List<double> data) {
    if (data.length < 2) return 0.0;
    double mean = data.reduce((a, b) => a + b) / data.length;
    double sumSq = data.fold(0.0, (sum, x) => sum + pow(x - mean, 2));
    return sumSq / data.length;
  }

  String _fatigueLevel(double score) {
    if (score >= 0.8) return 'CRITIQUE';
    if (score >= 0.6) return 'ÉLEVÉ';
    if (score >= 0.4) return 'MODÉRÉ';
    if (score >= 0.2) return 'FAIBLE';
    return 'NORMAL';
  }

  String _riskLevel(double score) {
    if (score >= 0.7) return 'DANGEREUX';
    if (score >= 0.4) return 'RISQUÉ';
    if (score >= 0.2) return 'PRUDENT';
    return 'SÉCURISÉ';
  }

  String _healthLevel(double score) {
    if (score >= 0.8) return 'EXCELLENT';
    if (score >= 0.6) return 'BON';
    if (score >= 0.4) return 'ATTENTION';
    if (score >= 0.2) return 'CRITIQUE';
    return 'PANNE IMMINENTE';
  }

  List<String> _generateAlerts(double fatigue, double driving, double engine,
      double fuelTheft, String camion) {
    final alerts = <String>[];
    if (fatigue >= 0.7) {
      alerts.add('⚠️ Chauffeur potentiellement épuisé — pause obligatoire');
    }
    if (fatigue >= 0.5 && fatigue < 0.7) {
      alerts.add('💤 Fatigue modérée détectée — surveiller');
    }
    if (driving >= 0.6) {
      alerts.add('🚨 Conduite dangereuse détectée');
    }
    if (engine < 0.4) {
      alerts.add('🔧 Santé moteur dégradée — maintenance requise');
    }
    if (fuelTheft > 0.3) {
      alerts.add('⛽ Anomalie de carburant suspecte');
    }
    return alerts;
  }
}

// ─── État interne par véhicule ───────────────────────────────────────────

class _VehicleAiState {
  double lastFatigueScore = 0.0;
  double lastDrivingRisk = 0.0;
  double lastFuelTheftScore = 0.0;
  double? lastFuelLevel;
  DateTime? fuelCheckTimestamp;
  int totalBrakes = 0;
  int totalOverspeeds = 0;
  List<double> rpmHistory = [];
}

// ─── Résultat de l'Analyse Complète ──────────────────────────────────────

class FleetAiResult {
  final double fatigueRisk;     // 0.0 → 1.0
  final double drivingRisk;     // 0.0 → 1.0
  final double engineHealth;    // 1.0 → 0.0 (1.0 = parfait)
  final double fuelTheftRisk;   // 0.0 → 1.0
  final double ecoScore;        // 0 → 100
  final String fatigueLevel;    // NORMAL / FAIBLE / MODÉRÉ / ÉLEVÉ / CRITIQUE
  final String drivingLevel;    // SÉCURISÉ / PRUDENT / RISQUÉ / DANGEREUX
  final String engineLevel;     // EXCELLENT / BON / ATTENTION / CRITIQUE / PANNE IMMINENTE
  final List<String> alerts;

  const FleetAiResult({
    required this.fatigueRisk,
    required this.drivingRisk,
    required this.engineHealth,
    required this.fuelTheftRisk,
    required this.ecoScore,
    required this.fatigueLevel,
    required this.drivingLevel,
    required this.engineLevel,
    required this.alerts,
  });
}
