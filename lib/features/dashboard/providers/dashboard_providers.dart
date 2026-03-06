import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleetguard/core/providers.dart';
import '../models/dashboard_models.dart';

/// Statistiques globales (KPI). En prod : AsyncValue depuis API/Firebase.
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  return const DashboardStats();
});

/// Camions avec données temps réel. En prod : stream depuis Firebase/WebSocket.
final dashboardTrucksProvider = FutureProvider<List<DashboardTruck>>((
  ref,
) async {
  final repo = ref.watch(truckRepositoryProvider);
  final list = repo.initialTrucks();
  return list.asMap().entries.map((e) {
    final i = e.key;
    final t = e.value;
    return DashboardTruck(
      id: t.id,
      plate: t.plate,
      driverName: i < 3 ? 'Chauffeur ${i + 1}' : null,
      status: i % 4 == 0
          ? TruckStatus.warning
          : (i % 3 == 0 ? TruckStatus.maintenance : TruckStatus.active),
      speedKmh: i < 8 ? 50.0 + (i * 7) : null,
      engineTempC: i < 8 ? 75.0 + (i * 3) : null,
      fuelPercent: i < 8 ? 100 - (i * 8) : null,
      lat: 36.8 + (i * 0.01),
      lng: 10.15 + (i * 0.02),
    );
  }).toList();
});

/// Alertes actives. En prod : stream depuis Firebase.
final dashboardAlertsProvider = FutureProvider<List<DashboardAlert>>((
  ref,
) async {
  await Future.delayed(const Duration(milliseconds: 100));
  return [
    DashboardAlert(
      id: 'a1',
      truckId: '1',
      truckPlate: '144 TUN 147',
      type: 'Température moteur',
      message: 'Seuil dépassé',
      valueAndThreshold: '98 °C / 95 °C',
      at: DateTime.now().subtract(const Duration(minutes: 12)),
      severity: AlertSeverity.critical,
    ),
    DashboardAlert(
      id: 'a2',
      truckId: '2',
      truckPlate: '205 TUN 186',
      type: 'Carburant bas',
      message: 'Réserver essence',
      valueAndThreshold: '12 %',
      at: DateTime.now().subtract(const Duration(minutes: 45)),
      severity: AlertSeverity.warning,
    ),
    DashboardAlert(
      id: 'a3',
      truckId: '3',
      truckPlate: '151 TUN 2345',
      type: 'Vitesse élevée',
      message: 'Dépassement 120 km/h',
      valueAndThreshold: '127 km/h',
      at: DateTime.now().subtract(const Duration(minutes: 2)),
      severity: AlertSeverity.warning,
    ),
  ];
});

/// Voyages en cours. En prod : depuis API tRPC / Firestore.
final dashboardTripsProvider = FutureProvider<List<DashboardTrip>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 80));
  return [
    const DashboardTrip(
      id: 't1',
      clientName: 'STEG',
      destination: 'Tunis → Sfax',
      driverName: 'Mohamed B.',
      truckPlate: '144 TUN 147',
      progressPercent: 65,
      estimatedTimeRemaining: '2h 15',
      status: 'En cours',
    ),
    const DashboardTrip(
      id: 't2',
      clientName: 'Carrefour',
      destination: 'Sousse → Bizerte',
      driverName: 'Ali K.',
      truckPlate: '205 TUN 186',
      progressPercent: 22,
      estimatedTimeRemaining: '4h 30',
      status: 'En cours',
    ),
    const DashboardTrip(
      id: 't3',
      clientName: 'Magasin Général',
      destination: 'Tunis → Nabeul',
      driverName: 'Hassan F.',
      truckPlate: '151 TUN 2345',
      progressPercent: 88,
      estimatedTimeRemaining: '0h 45',
      status: 'En cours',
    ),
  ];
});

/// Données pour les graphiques (voyages/jour, revenus/jour). En prod : API.
final dashboardChartDataProvider = FutureProvider<DashboardChartData>((
  ref,
) async {
  await Future.delayed(const Duration(milliseconds: 50));
  return const DashboardChartData(
    tripsPerDay: [12, 15, 14, 18, 16, 20, 18],
    revenuePerDayTnd: [3200, 3800, 3500, 4200, 4100, 4500, 4250],
    statusDistribution: {'Actif': 18, 'Maintenance': 4, 'Inactif': 2},
    topConsumption: [
      ('144 TUN 147', 42.5),
      ('205 TUN 186', 38.2),
      ('151 TUN 2345', 35.0),
      ('222 TUN 4356', 33.1),
      ('189 TUN 4469', 30.8),
    ],
  );
});

/// Agrégat des données pour les graphiques.
class DashboardChartData {
  final List<int> tripsPerDay;
  final List<double> revenuePerDayTnd;
  final Map<String, int> statusDistribution;
  final List<(String, double)> topConsumption;

  const DashboardChartData({
    this.tripsPerDay = const [12, 15, 14, 18, 16, 20, 18],
    this.revenuePerDayTnd = const [3200, 3800, 3500, 4200, 4100, 4500, 4250],
    this.statusDistribution = const {
      'Actif': 18,
      'Maintenance': 4,
      'Inactif': 2,
    },
    this.topConsumption = const [
      ('144 TUN 147', 42.5),
      ('205 TUN 186', 38.2),
      ('151 TUN 2345', 35.0),
      ('222 TUN 4356', 33.1),
      ('189 TUN 4469', 30.8),
    ],
  });
}
