import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver.dart';

/// Provider pour la liste des chauffeurs
final driversProvider =
    StateNotifierProvider<DriversNotifier, AsyncValue<List<Driver>>>(
      (ref) => DriversNotifier(),
    );

/// Provider pour les filtres
final driverFiltersProvider = StateProvider<DriverFilters>(
  (ref) => const DriverFilters(),
);

/// Provider pour les chauffeurs filtrés
final filteredDriversProvider = Provider<AsyncValue<List<Driver>>>((ref) {
  final driversState = ref.watch(driversProvider);
  final filters = ref.watch(driverFiltersProvider);

  return driversState.when(
    data: (drivers) {
      var filtered = drivers;

      // Filtre de recherche
      if (filters.searchQuery.isNotEmpty) {
        final query = filters.searchQuery.toLowerCase();
        filtered = filtered.where((d) {
          return d.fullName.toLowerCase().contains(query) ||
              d.email.toLowerCase().contains(query) ||
              d.phone.contains(query) ||
              d.driverId.toLowerCase().contains(query);
        }).toList();
      }

      // Filtre de statut
      if (filters.status != null) {
        filtered = filtered.where((d) => d.status == filters.status).toList();
      }

      // Filtre d'expérience
      if (filters.minExperience != null) {
        filtered = filtered
            .where((d) => d.experienceYears >= filters.minExperience!)
            .toList();
      }
      if (filters.maxExperience != null) {
        filtered = filtered
            .where((d) => d.experienceYears <= filters.maxExperience!)
            .toList();
      }

      // Filtre de notation
      if (filters.minRating != null) {
        filtered = filtered
            .where((d) => d.rating >= filters.minRating!)
            .toList();
      }

      // Filtre véhicule assigné
      if (filters.hasVehicle != null) {
        filtered = filtered
            .where(
              (d) => filters.hasVehicle!
                  ? d.assignedVehicle != null
                  : d.assignedVehicle == null,
            )
            .toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider pour le chauffeur sélectionné
final selectedDriverProvider = StateProvider<Driver?>((ref) => null);

/// Provider pour la sélection multiple
final selectedDriversProvider =
    StateNotifierProvider<SelectedDriversNotifier, Set<String>>(
      (ref) => SelectedDriversNotifier(),
    );

/// Provider pour le mode sombre
final darkModeProvider = StateProvider<bool>((ref) => false);

/// Notifier pour les chauffeurs
class DriversNotifier extends StateNotifier<AsyncValue<List<Driver>>> {
  DriversNotifier() : super(const AsyncValue.loading()) {
    loadDrivers();
  }

  Future<void> loadDrivers() async {
    try {
      // Simuler un chargement depuis une API
      await Future.delayed(const Duration(milliseconds: 500));

      // Données de test
      final drivers = _generateMockDrivers();
      state = AsyncValue.data(drivers);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addDriver(Driver driver) async {
    try {
      state.whenData((drivers) {
        state = AsyncValue.data([...drivers, driver]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateDriver(Driver updatedDriver) async {
    try {
      state.whenData((drivers) {
        final index = drivers.indexWhere((d) => d.id == updatedDriver.id);
        if (index != -1) {
          final newDrivers = [...drivers];
          newDrivers[index] = updatedDriver;
          state = AsyncValue.data(newDrivers);
        }
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteDriver(String driverId) async {
    try {
      state.whenData((drivers) {
        state = AsyncValue.data(
          drivers.where((d) => d.id != driverId).toList(),
        );
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteDrivers(Set<String> driverIds) async {
    try {
      state.whenData((drivers) {
        state = AsyncValue.data(
          drivers.where((d) => !driverIds.contains(d.id)).toList(),
        );
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateDriverStatus(String driverId, DriverStatus status) async {
    try {
      state.whenData((drivers) {
        final index = drivers.indexWhere((d) => d.id == driverId);
        if (index != -1) {
          final newDrivers = [...drivers];
          newDrivers[index] = drivers[index].copyWith(status: status);
          state = AsyncValue.data(newDrivers);
        }
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateDriversStatus(
    Set<String> driverIds,
    DriverStatus status,
  ) async {
    try {
      state.whenData((drivers) {
        final newDrivers = drivers.map((d) {
          if (driverIds.contains(d.id)) {
            return d.copyWith(status: status);
          }
          return d;
        }).toList();
        state = AsyncValue.data(newDrivers);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  List<Driver> _generateMockDrivers() {
    final now = DateTime.now();
    return [
      Driver(
        id: '1',
        firstName: 'Ahmed',
        lastName: 'Ben Ali',
        email: 'ahmed.benali@example.com',
        phone: '+216 20 123 456',
        birthDate: DateTime(1985, 3, 15),
        address: '15 Rue de la République',
        city: 'Tunis',
        postalCode: '1000',
        country: 'Tunisie',
        hireDate: DateTime(2020, 1, 10),
        licenseCategory: LicenseCategory.c,
        licenseNumber: 'TN-123456-85',
        licenseExpiryDate: DateTime(2026, 3, 15),
        monthlySalary: 2500.0,
        status: DriverStatus.active,
        assignedVehicle: const AssignedVehicle(
          id: 'v1',
          plate: '123 TU 456',
          brand: 'Mercedes',
          model: 'Actros',
          year: 2021,
          mileage: 85000.0,
          status: 'active',
        ),
        totalTrips: 145,
        monthlyTrips: 12,
        weeklyTrips: 3,
        totalMileage: 45000.0,
        monthlyMileage: 3200.0,
        totalRevenue: 125000.0,
        monthlyRevenue: 8500.0,
        rating: 4.8,
        ratingCount: 42,
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now,
      ),
      Driver(
        id: '2',
        firstName: 'Mohamed',
        lastName: 'Trabelsi',
        email: 'mohamed.trabelsi@example.com',
        phone: '+216 21 234 567',
        birthDate: DateTime(1988, 7, 22),
        address: '25 Avenue Habib Bourguiba',
        city: 'Sfax',
        postalCode: '3000',
        country: 'Tunisie',
        hireDate: DateTime(2021, 6, 15),
        licenseCategory: LicenseCategory.c,
        licenseNumber: 'TN-234567-88',
        licenseExpiryDate: DateTime(2027, 7, 22),
        monthlySalary: 2300.0,
        status: DriverStatus.active,
        assignedVehicle: const AssignedVehicle(
          id: 'v2',
          plate: '456 SF 789',
          brand: 'Volvo',
          model: 'FH',
          year: 2022,
          mileage: 45000.0,
          status: 'active',
        ),
        totalTrips: 89,
        monthlyTrips: 8,
        weeklyTrips: 2,
        totalMileage: 28000.0,
        monthlyMileage: 2100.0,
        totalRevenue: 78000.0,
        monthlyRevenue: 6200.0,
        rating: 4.5,
        ratingCount: 28,
        createdAt: now.subtract(const Duration(days: 300)),
        updatedAt: now,
      ),
      Driver(
        id: '3',
        firstName: 'Karim',
        lastName: 'Bouaziz',
        email: 'karim.bouaziz@example.com',
        phone: '+216 22 345 678',
        birthDate: DateTime(1990, 11, 8),
        address: '10 Rue Ibn Khaldoun',
        city: 'Sousse',
        postalCode: '4000',
        country: 'Tunisie',
        hireDate: DateTime(2022, 3, 1),
        licenseCategory: LicenseCategory.d,
        licenseNumber: 'TN-345678-90',
        licenseExpiryDate: DateTime(2025, 11, 8),
        monthlySalary: 2200.0,
        status: DriverStatus.onLeave,
        assignedVehicle: null,
        totalTrips: 56,
        monthlyTrips: 0,
        weeklyTrips: 0,
        totalMileage: 18000.0,
        monthlyMileage: 0.0,
        totalRevenue: 45000.0,
        monthlyRevenue: 0.0,
        rating: 4.2,
        ratingCount: 15,
        createdAt: now.subtract(const Duration(days: 250)),
        updatedAt: now,
      ),
      Driver(
        id: '4',
        firstName: 'Hassen',
        lastName: 'Jebali',
        email: 'hassen.jebali@example.com',
        phone: '+216 23 456 789',
        birthDate: DateTime(1982, 5, 30),
        address: '8 Rue de l\'Indépendance',
        city: 'Gabès',
        postalCode: '6000',
        country: 'Tunisie',
        hireDate: DateTime(2019, 9, 20),
        licenseCategory: LicenseCategory.e,
        licenseNumber: 'TN-456789-82',
        licenseExpiryDate: DateTime(2026, 5, 30),
        monthlySalary: 2800.0,
        status: DriverStatus.active,
        assignedVehicle: const AssignedVehicle(
          id: 'v3',
          plate: '789 GB 123',
          brand: 'Scania',
          model: 'R450',
          year: 2020,
          mileage: 120000.0,
          status: 'active',
        ),
        totalTrips: 234,
        monthlyTrips: 18,
        weeklyTrips: 4,
        totalMileage: 78000.0,
        monthlyMileage: 5200.0,
        totalRevenue: 195000.0,
        monthlyRevenue: 12000.0,
        rating: 4.9,
        ratingCount: 67,
        createdAt: now.subtract(const Duration(days: 450)),
        updatedAt: now,
      ),
      Driver(
        id: '5',
        firstName: 'Nabil',
        lastName: 'Khalfallah',
        email: 'nabil.khalfallah@example.com',
        phone: '+216 24 567 890',
        birthDate: DateTime(1992, 2, 14),
        address: '42 Avenue de Carthage',
        city: 'Ariana',
        postalCode: '2080',
        country: 'Tunisie',
        hireDate: DateTime(2023, 1, 5),
        licenseCategory: LicenseCategory.c,
        licenseNumber: 'TN-567890-92',
        licenseExpiryDate: DateTime(2028, 2, 14),
        monthlySalary: 2000.0,
        status: DriverStatus.inactive,
        assignedVehicle: null,
        totalTrips: 23,
        monthlyTrips: 0,
        weeklyTrips: 0,
        totalMileage: 6500.0,
        monthlyMileage: 0.0,
        totalRevenue: 15000.0,
        monthlyRevenue: 0.0,
        rating: 3.8,
        ratingCount: 8,
        createdAt: now.subtract(const Duration(days: 150)),
        updatedAt: now,
      ),
      Driver(
        id: '6',
        firstName: 'Sami',
        lastName: 'Gharbi',
        email: 'sami.gharbi@example.com',
        phone: '+216 25 678 901',
        birthDate: DateTime(1987, 9, 3),
        address: '18 Rue Mongi Slim',
        city: 'Bizerte',
        postalCode: '7000',
        country: 'Tunisie',
        hireDate: DateTime(2020, 11, 12),
        licenseCategory: LicenseCategory.c,
        licenseNumber: 'TN-678901-87',
        licenseExpiryDate: DateTime(2026, 9, 3),
        monthlySalary: 2400.0,
        status: DriverStatus.suspended,
        assignedVehicle: null,
        totalTrips: 112,
        monthlyTrips: 0,
        weeklyTrips: 0,
        totalMileage: 35000.0,
        monthlyMileage: 0.0,
        totalRevenue: 95000.0,
        monthlyRevenue: 0.0,
        rating: 3.5,
        ratingCount: 31,
        createdAt: now.subtract(const Duration(days: 380)),
        updatedAt: now,
      ),
      Driver(
        id: '7',
        firstName: 'Ridha',
        lastName: 'Mansour',
        email: 'ridha.mansour@example.com',
        phone: '+216 26 789 012',
        birthDate: DateTime(1984, 12, 25),
        address: '5 Rue du Commerce',
        city: 'Monastir',
        postalCode: '5000',
        country: 'Tunisie',
        hireDate: DateTime(2018, 4, 18),
        licenseCategory: LicenseCategory.d,
        licenseNumber: 'TN-789012-84',
        licenseExpiryDate: DateTime(2027, 12, 25),
        monthlySalary: 3000.0,
        status: DriverStatus.active,
        assignedVehicle: const AssignedVehicle(
          id: 'v4',
          plate: '012 MN 345',
          brand: 'MAN',
          model: 'TGX',
          year: 2019,
          mileage: 150000.0,
          status: 'active',
        ),
        totalTrips: 312,
        monthlyTrips: 22,
        weeklyTrips: 5,
        totalMileage: 95000.0,
        monthlyMileage: 6500.0,
        totalRevenue: 245000.0,
        monthlyRevenue: 14500.0,
        rating: 4.7,
        ratingCount: 89,
        createdAt: now.subtract(const Duration(days: 600)),
        updatedAt: now,
      ),
    ];
  }
}

/// Notifier pour la sélection multiple
class SelectedDriversNotifier extends StateNotifier<Set<String>> {
  SelectedDriversNotifier() : super({});

  void toggleSelection(String driverId) {
    if (state.contains(driverId)) {
      state = {...state}..remove(driverId);
    } else {
      state = {...state, driverId};
    }
  }

  void selectAll(List<String> driverIds) {
    state = {...driverIds};
  }

  void clearSelection() {
    state = {};
  }

  bool isSelected(String driverId) => state.contains(driverId);
}
