/// Modèles pour le dashboard SHTT (données métier + temps réel).

/// Statistiques globales du dashboard.
class DashboardStats {
  final int activeTrucks;
  final int tripsToday;
  final double revenueTodayTnd;
  final int activeAlerts;
  final int criticalAlerts;
  final String activeTrucksTrend;
  final String tripsTrend;
  final String revenueTrend;
  final String alertsSummary;

  const DashboardStats({
    this.activeTrucks = 24,
    this.tripsToday = 18,
    this.revenueTodayTnd = 4250,
    this.activeAlerts = 3,
    this.criticalAlerts = 2,
    this.activeTrucksTrend = '+2 depuis hier',
    this.tripsTrend = '+5 depuis hier',
    this.revenueTrend = '+12% vs hier',
    this.alertsSummary = '2 critiques',
  });
}

/// Statut d'un camion pour la carte et les listes.
enum TruckStatus { active, inactive, maintenance, warning, critical }

/// Camion avec données temps réel (OBD2 + GPS) pour le dashboard.
class DashboardTruck {
  final String id;
  final String plate;
  final String? driverName;
  final TruckStatus status;
  final double? speedKmh;
  final double? engineTempC;
  final double? fuelPercent;
  final double? lat;
  final double? lng;
  final String? currentTripId;

  const DashboardTruck({
    required this.id,
    required this.plate,
    this.driverName,
    this.status = TruckStatus.active,
    this.speedKmh,
    this.engineTempC,
    this.fuelPercent,
    this.lat,
    this.lng,
    this.currentTripId,
  });
}

/// Sévérité d'une alerte.
enum AlertSeverity { info, warning, critical }

/// Alerte affichée dans la section alertes.
class DashboardAlert {
  final String id;
  final String truckId;
  final String truckPlate;
  final String type;
  final String message;
  final String? valueAndThreshold;
  final DateTime at;
  final AlertSeverity severity;
  final bool read;

  const DashboardAlert({
    required this.id,
    required this.truckId,
    required this.truckPlate,
    required this.type,
    required this.message,
    this.valueAndThreshold,
    required this.at,
    this.severity = AlertSeverity.warning,
    this.read = false,
  });
}

/// Voyage en cours pour la section voyages.
class DashboardTrip {
  final String id;
  final String clientName;
  final String destination;
  final String driverName;
  final String truckPlate;
  final double progressPercent;
  final String? estimatedTimeRemaining;
  final String status;

  const DashboardTrip({
    required this.id,
    required this.clientName,
    required this.destination,
    required this.driverName,
    required this.truckPlate,
    this.progressPercent = 0,
    this.estimatedTimeRemaining,
    this.status = 'En cours',
  });
}
