import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/truck.dart';
import 'repositories/truck_repository.dart';

// Repository provider
final truckRepositoryProvider = Provider<TruckRepository>((ref) {
  return const TruckRepository();
});

// Trucks list provider (in-memory for now)
final trucksProvider = StateProvider<List<Truck>>((ref) {
  final repo = ref.read(truckRepositoryProvider);
  final list = repo.initialTrucks();
  // Optionally sort by plate
  list.sort((a, b) => a.plate.compareTo(b.plate));
  return list;
});
