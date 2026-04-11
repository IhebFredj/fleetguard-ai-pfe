import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gps_service.dart';

/// Service qui synchronise les positions GPS Alpha Technology → Supabase
/// toutes les 30 secondes. Fonctionne en arrière-plan.
class GpsSyncService {
  static final GpsSyncService _instance = GpsSyncService._internal();
  factory GpsSyncService() => _instance;
  GpsSyncService._internal();

  final GpsService _gpsService = GpsService();
  final _supabase = Supabase.instance.client;

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isRunning = false;
  DateTime? _lastSyncTime;
  int _syncCount = 0;
  int _errorCount = 0;

  /// Démarre la synchronisation GPS en arrière-plan
  void start({Duration interval = const Duration(seconds: 30)}) {
    if (_isRunning) {
      debugPrint('📍 [GPS-SYNC] Déjà en cours');
      return;
    }

    _isRunning = true;
    debugPrint('📍 [GPS-SYNC] ✅ Démarré — intervalle: ${interval.inSeconds}s');

    // Première sync immédiate
    _syncNow();

    // Puis toutes les 30s
    _syncTimer = Timer.periodic(interval, (_) => _syncNow());
  }

  /// Arrête la synchronisation
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isRunning = false;
    debugPrint('📍 [GPS-SYNC] ⏹ Arrêté (total syncs: $_syncCount, erreurs: $_errorCount)');
  }

  /// Force une synchronisation maintenant
  Future<void> _syncNow() async {
    if (_isSyncing) return; // Éviter les appels concurrents
    _isSyncing = true;

    try {
      // 1. Récupérer les véhicules depuis Alpha Technology
      final vehicles = await _gpsService.fetchAlphaVehicles();

      if (vehicles.isEmpty) {
        debugPrint('📍 [GPS-SYNC] ⚠ Aucun véhicule reçu');
        _isSyncing = false;
        return;
      }

      // 2. Préparer les données pour upsert
      final rows = vehicles.map((v) => {
        'matricule': v.matricule,
        'lat': v.lat,
        'lng': v.lng,
        'vitesse': v.vitesse,
        'angle': v.angle,
        'etat': v.etat,
        'adresse': v.adresse,
        'carburant': v.carburant,
        'kilometrage': v.kilometrage,
        'rpm': v.rpm,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).toList();

      // 3. Upsert dans Supabase (INSERT ou UPDATE si le matricule existe)
      await _supabase
          .from('vehicle_positions')
          .upsert(rows, onConflict: 'matricule');

      _syncCount++;
      _lastSyncTime = DateTime.now();
      debugPrint(
        '📍 [GPS-SYNC] ✔ Sync #$_syncCount — ${vehicles.length} véhicules '
        '→ Supabase (${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')})',
      );
    } catch (e) {
      _errorCount++;
      debugPrint('📍 [GPS-SYNC] ✘ Erreur sync #$_errorCount: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Getters pour le monitoring
  bool get isRunning => _isRunning;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get syncCount => _syncCount;
  int get errorCount => _errorCount;
}
