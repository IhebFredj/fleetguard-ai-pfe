import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kDanger = Color(0xFFEF4444);
const _kWarning = Color(0xFFF59E0B);
const _kBackground = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────

final adminTripsHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // 1. Fetch all completed/cancelled/received trips with joins
  final res = await supabase
      .from('trips')
      .select('''
        *,
        trip_validations(*),
        trip_vehicles(truck_id, trucks(*))
      ''')
      .inFilter('status', ['completed', 'cancelled', 'received'])
      .order('created_at', ascending: false);

  final trips = (res as List).map((e) => e as Map<String, dynamic>).toList();

  // 2. Fetch all drivers and build a truck_id → driver map
  try {
    final driversRes = await supabase.from('drivers').select('*');
    
    debugPrint('=== ADMIN TRIPS PROVIDER DEBUG ===');
    debugPrint('  Total trips fetched: ${trips.length}');
    debugPrint('  Total drivers fetched: ${(driversRes as List).length}');
    
    // Map: truck_id → driver info (a driver has a truck_id field)
    final Map<String, Map<String, dynamic>> truckToDriver = {};
    for (final d in driversRes) {
      final dMap = d as Map<String, dynamic>;
      debugPrint('  Driver: ${dMap['full_name'] ?? dMap['first_name']} => truck_id: ${dMap['truck_id']}');
      if (dMap['truck_id'] != null) {
        truckToDriver[dMap['truck_id'].toString()] = dMap;
      }
    }
    debugPrint('  truckToDriver map: ${truckToDriver.keys.toList()}');
    
    // 3. Attach driver and truck data to each trip
    for (var trip in trips) {
      // Find the truck_id from trip_vehicles
      String? tripTruckId;
      if (trip['trip_vehicles'] != null && (trip['trip_vehicles'] as List).isNotEmpty) {
        final vehicle = trip['trip_vehicles'][0];
        tripTruckId = vehicle['truck_id']?.toString();
      }
      
      // Also check validation truck
      if (trip['trip_validations'] != null && (trip['trip_validations'] as List).isNotEmpty) {
        final val = trip['trip_validations'][0];
        final valTruckId = val['truck_used_id']?.toString();
        if (valTruckId != null) {
          tripTruckId ??= valTruckId; // Use validation truck as fallback
        }
      }
      
      debugPrint('  Trip ${trip['id']}: tripTruckId=$tripTruckId, match=${truckToDriver.containsKey(tripTruckId)}');
      
      // Map driver from truck assignment
      if (tripTruckId != null && truckToDriver.containsKey(tripTruckId)) {
        trip['drivers'] = truckToDriver[tripTruckId];
      }
    }
  } catch (e) {
    debugPrint('Erreur mapping drivers/trucks: $e');
  }

  return trips;
});

// ─────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────

class AdminTripListScreen extends ConsumerStatefulWidget {
  const AdminTripListScreen({super.key});

  @override
  ConsumerState<AdminTripListScreen> createState() => _AdminTripListScreenState();
}

class _AdminTripListScreenState extends ConsumerState<AdminTripListScreen> {
  String _statusFilter = 'all';
  String? _filterDriver;
  String? _filterTruck;
  String? _filterDeparture;
  String? _filterDestination;

  // Helper to extract driver name from trip
  String _getDriverName(Map<String, dynamic> trip) {
    final driver = trip['drivers'];
    if (driver != null && driver is Map) {
      final fn = driver['first_name'] ?? '';
      final ln = driver['last_name'] ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) return full;
      if (driver['full_name'] != null && driver['full_name'].toString().trim().isNotEmpty) {
        return driver['full_name'];
      }
    }
    return '';
  }

  // Helper to extract truck plate from trip
  String _getTruckPlate(Map<String, dynamic> trip) {
    try {
      if (trip['trip_vehicles'] != null && (trip['trip_vehicles'] as List).isNotEmpty) {
        final vehicle = trip['trip_vehicles'][0];
        final trucksData = vehicle['trucks'];
        if (trucksData is Map) {
          return trucksData['plate']?.toString() 
              ?? trucksData['id']?.toString().replaceAll('_', ' ') 
              ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  // Get unique values for dropdowns
  List<String> _uniqueValues(List<Map<String, dynamic>> trips, String Function(Map<String, dynamic>) extractor) {
    final values = trips.map(extractor).where((v) => v.isNotEmpty && v != 'Inconnu').toSet().toList();
    values.sort();
    return values;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> trips) {
    var filtered = trips;

    // 1. Status filter
    switch (_statusFilter) {
      case 'completed':
        filtered = filtered.where((t) => 
          t['admin_received_docs'] != true && t['has_problem'] != true
        ).toList();
        break;
      case 'received':
        filtered = filtered.where((t) => 
          t['admin_received_docs'] == true && t['has_problem'] != true
        ).toList();
        break;
      case 'problem':
        filtered = filtered.where((t) => 
          t['has_problem'] == true && t['admin_received_docs'] != true
        ).toList();
        break;
      case 'received_alert':
        filtered = filtered.where((t) => 
          t['admin_received_docs'] == true && t['has_problem'] == true
        ).toList();
        break;
    }

    // 2. Dropdown filters
    if (_filterDriver != null) {
      filtered = filtered.where((t) => _getDriverName(t) == _filterDriver).toList();
    }
    if (_filterTruck != null) {
      filtered = filtered.where((t) => _getTruckPlate(t) == _filterTruck).toList();
    }
    if (_filterDeparture != null) {
      filtered = filtered.where((t) => (t['departure'] ?? '') == _filterDeparture).toList();
    }
    if (_filterDestination != null) {
      filtered = filtered.where((t) => (t['destination'] ?? '') == _filterDestination).toList();
    }

    return filtered;
  }

  // Counts for filter chips
  Map<String, int> _getCounts(List<Map<String, dynamic>> trips) {
    int completed = 0, received = 0, problem = 0, receivedAlert = 0;
    for (final t in trips) {
      final isReceived = t['admin_received_docs'] == true;
      final hasProblem = t['has_problem'] == true;
      if (isReceived && hasProblem) {
        receivedAlert++;
      } else if (isReceived) {
        received++;
      } else if (hasProblem) {
        problem++;
      } else {
        completed++;
      }
    }
    return {
      'all': trips.length,
      'completed': completed,
      'received': received,
      'problem': problem,
      'received_alert': receivedAlert,
    };
  }

  bool get _hasActiveFilters => _filterDriver != null || _filterTruck != null || _filterDeparture != null || _filterDestination != null;

  void _clearAllFilters() {
    setState(() {
      _filterDriver = null;
      _filterTruck = null;
      _filterDeparture = null;
      _filterDestination = null;
      _statusFilter = 'all';
    });
  }

  void _showFilterDropdown(String title, List<String> options, String? current, ValueChanged<String?> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _kTextSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.filter, size: 18, color: _kPrimary),
                const SizedBox(width: 10),
                Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                const Spacer(),
                if (current != null)
                  TextButton(
                    onPressed: () { onSelected(null); Navigator.pop(ctx); },
                    child: Text('Effacer', style: GoogleFonts.inter(color: _kDanger, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final val = options[i];
                final isSelected = val == current;
                return ListTile(
                  dense: true,
                  title: Text(val, style: GoogleFonts.inter(color: isSelected ? _kPrimary : _kTextPrimary, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400, fontSize: 14)),
                  trailing: isSelected ? const Icon(LucideIcons.check, color: _kPrimary, size: 18) : null,
                  onTap: () { onSelected(val); Navigator.pop(ctx); },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(adminTripsHistoryProvider);

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        title: Text('Suivi des Bons', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _kTextPrimary, fontSize: 18)),
        backgroundColor: _kCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(LucideIcons.filterX, color: _kDanger),
              tooltip: 'Effacer filtres',
              onPressed: _clearAllFilters,
            ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(adminTripsHistoryProvider),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: _kDanger))),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.folderCheck, size: 64, color: _kTextSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('Aucun voyage terminé', style: GoogleFonts.poppins(fontSize: 18, color: _kTextSecondary)),
                ],
              ),
            );
          }

          final counts = _getCounts(trips);
          final filteredTrips = _applyFilters(trips);
          final driverNames = _uniqueValues(trips, _getDriverName);
          final truckPlates = _uniqueValues(trips, _getTruckPlate);
          final departures = _uniqueValues(trips, (t) => (t['departure'] ?? '').toString());
          final destinations = _uniqueValues(trips, (t) => (t['destination'] ?? '').toString());

          return Column(
            children: [
              // ── Dropdown Filters ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(child: _buildDropdownButton(LucideIcons.user, 'Chauffeur', _filterDriver, driverNames, (v) => setState(() => _filterDriver = v))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildDropdownButton(LucideIcons.truck, 'Camion', _filterTruck, truckPlates, (v) => setState(() => _filterTruck = v))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: _buildDropdownButton(LucideIcons.mapPin, 'Départ', _filterDeparture, departures, (v) => setState(() => _filterDeparture = v))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildDropdownButton(LucideIcons.flag, 'Destination', _filterDestination, destinations, (v) => setState(() => _filterDestination = v))),
                  ],
                ),
              ),

              // ── Status chips ──
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('all', 'Tous', counts['all']!, _kPrimary),
                    _buildFilterChip('completed', 'Non reçu', counts['completed']!, _kWarning),
                    _buildFilterChip('received', 'Reçu', counts['received']!, _kAccent),
                    _buildFilterChip('problem', 'Problème', counts['problem']!, _kDanger),
                    _buildFilterChip('received_alert', 'Reçu+Alerte', counts['received_alert']!, Colors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ── Results count ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Row(
                  children: [
                    Text('${filteredTrips.length} résultat(s)', style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
                    if (_hasActiveFilters) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: _clearAllFilters,
                        child: Text('Effacer tout', style: GoogleFonts.inter(fontSize: 12, color: _kDanger, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ── List ──
              Expanded(
                child: filteredTrips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.searchX, size: 48, color: _kTextSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('Aucun résultat', style: GoogleFonts.poppins(fontSize: 16, color: _kTextSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filteredTrips.length,
                      itemBuilder: (context, index) {
                        final trip = filteredTrips[index];
                        return _AdminTripCard(trip: trip, onUpdate: () => ref.invalidate(adminTripsHistoryProvider));
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownButton(IconData icon, String label, String? value, List<String> options, ValueChanged<String?> onSelected) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: () => _showFilterDropdown('Filtrer par $label', options, value, onSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue ? _kPrimary.withValues(alpha: 0.1) : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasValue ? _kPrimary.withValues(alpha: 0.4) : _kTextSecondary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: hasValue ? _kPrimary : _kTextSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value ?? label,
                style: GoogleFonts.inter(fontSize: 12, color: hasValue ? _kPrimary : _kTextSecondary, fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 14, color: hasValue ? _kPrimary : _kTextSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count, Color color) {
    final isActive = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? color : _kTextSecondary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? color : _kTextSecondary)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: isActive ? color : _kTextSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? Colors.white : _kTextSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onUpdate;

  const _AdminTripCard({required this.trip, required this.onUpdate});

  @override
  State<_AdminTripCard> createState() => _AdminTripCardState();
}

class _AdminTripCardState extends State<_AdminTripCard> {
  bool _isLoading = false;
  final TextEditingController _revenueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill if already exists
    if (widget.trip['revenue'] != null) {
      _revenueController.text = widget.trip['revenue'].toString();
    }
  }

  @override
  void dispose() {
    _revenueController.dispose();
    super.dispose();
  }

  Future<void> _markAsReceived() async {
    final revenue = double.tryParse(_revenueController.text) ?? 0.0;
    
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('trips')
          .update({
            'admin_received_docs': true,
            'status': 'received',
            'revenue': revenue,
          })
          .eq('id', widget.trip['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bon de livraison marqué comme reçu ✅'), backgroundColor: _kAccent),
        );
      }
      widget.onUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reportProblem() async {
    final reasons = ['Bon non reçu chez client', 'Bon illisible / flou', 'Bon perdu', 'Autre'];
    String? selected = reasons.first;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _kCard,
          title: Text('Signaler un problème', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => RadioListTile<String>(
              title: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              value: r,
              groupValue: selected,
              onChanged: (v) => setDialogState(() => selected = v),
              activeColor: _kDanger,
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(backgroundColor: _kDanger),
              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('trips')
          .update({
            'has_problem': true,
            'problem_reason': result,
            // Optionnel: on peut aussi changer le status en 'problem'
          })
          .eq('id', widget.trip['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Problème signalé : $result ⚠️'), backgroundColor: _kDanger),
        );
      }
      widget.onUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editRevenue() async {
    final TextEditingController editController = TextEditingController(text: widget.trip['revenue']?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Text('Modifier Revenu', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: editController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kBackground,
            hintText: 'Nouveau revenu',
            hintStyle: TextStyle(color: _kTextSecondary.withValues(alpha: 0.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _kTextSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, editController.text),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final newRev = double.tryParse(result) ?? 0.0;
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client
            .from('trips')
            .update({'revenue': newRev})
            .eq('id', widget.trip['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revenu mis à jour ✅'), backgroundColor: _kAccent));
        }
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showProofImage(BuildContext context, String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty || photoUrl == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune photo jointe ou URL invalide')));
      return;
    }
    
    // Quick fix: check if URL is just a name and prepend path if needed,
    // though getPublicUrl already does this normally.
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Bon de Livraison', style: TextStyle(color: Colors.white, fontSize: 16)),
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  onPressed: () => Supabase.instance.client.storage.from('trip-proofs').getPublicUrl(photoUrl), // Or use url_launcher
                )
              ],
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: InteractiveViewer(
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loading) {
                      if (loading == null) return child;
                      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context, error, stack) => Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.black26,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text('Impossible de charger l\'image', style: GoogleFonts.inter(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isCancelled = trip['status'] == 'cancelled';
    final isReceived = trip['admin_received_docs'] == true;
    final hasProblem = trip['has_problem'] == true;
    final problemReason = trip['problem_reason'] as String?;
    
    final dateRaw = trip['created_at'];
    final date = dateRaw != null ? DateTime.parse(dateRaw) : DateTime.now();
    
    // ── Debug: log trip data structure ──
    debugPrint('=== TRIP ${trip['id']} ===');
    debugPrint('  drivers: ${trip['drivers']}');
    debugPrint('  trip_vehicles: ${trip['trip_vehicles']}');
    debugPrint('  trip_validations keys: ${(trip['trip_validations'] as List?)?.map((v) => v.keys.toList())}');
    
    // ── Extract driver name ──
    final driver = trip['drivers'];
    String driverName = 'Chauffeur inconnu';
    if (driver != null && driver is Map) {
      final fn = driver['first_name'] ?? '';
      final ln = driver['last_name'] ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) {
        driverName = full;
      } else if (driver['full_name'] != null && driver['full_name'].toString().trim().isNotEmpty) {
        driverName = driver['full_name'];
      }
    }
    
    final valList = trip['trip_validations'] as List? ?? [];
    final validation = valList.isNotEmpty ? valList[0] as Map<String, dynamic> : null;
    final photoUrl = validation?['delivery_note_url'] as String?;
    final supplierTonnage = validation?['supplier_tonnage']?.toString() ?? 'N/A';
    final receivedTonnage = validation?['received_tonnage']?.toString() ?? 'N/A';
    
    // ── Extract truck plate – handle both Map and List from Supabase ──
    String truckPlate = 'Inconnu';
    try {
      // 1. Try from trip_vehicles join (always available)
      if (trip['trip_vehicles'] != null && (trip['trip_vehicles'] as List).isNotEmpty) {
        final vehicle = trip['trip_vehicles'][0];
        final trucksData = vehicle['trucks'];
        if (trucksData is Map) {
          truckPlate = trucksData['plate']?.toString()
              ?? trucksData['id']?.toString().replaceAll('_', ' ')
              ?? 'Inconnu';
        } else if (trucksData is List && trucksData.isNotEmpty) {
          truckPlate = trucksData[0]['plate']?.toString()
              ?? trucksData[0]['id']?.toString().replaceAll('_', ' ')
              ?? 'Inconnu';
        }
      }
    } catch (e) {
      debugPrint('  Erreur extraction truck plate: $e');
    }

    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isReceived ? _kAccent.withValues(alpha: 0.3) : _kTextSecondary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(date),
                style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isCancelled ? _kDanger : (isReceived ? _kAccent : _kPrimary)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCancelled 
                    ? 'Annulé' 
                    : (isReceived 
                        ? (hasProblem ? 'Reçu (Alerte)' : 'Reçu') 
                        : (hasProblem ? 'Problème' : 'Terminé')),
                  style: GoogleFonts.inter(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold, 
                    color: isCancelled 
                      ? _kDanger 
                      : (isReceived 
                          ? (hasProblem ? Colors.orange : _kAccent) 
                          : (hasProblem ? _kWarning : _kPrimary)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasProblem) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: (isReceived ? Colors.orange : _kDanger).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isReceived ? Colors.orange : _kDanger).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertTriangle, size: 16, color: isReceived ? Colors.orange : _kDanger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PROBLÈME : ${problemReason ?? 'Inconnu'}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isReceived ? Colors.orange : _kDanger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Infos
          Text(
            '${trip['departure'] ?? 'Inconnu'} ➔ ${trip['destination'] ?? 'Inconnu'}',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _kTextPrimary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.user, size: 14, color: _kTextSecondary),
              const SizedBox(width: 6),
              Text(driverName.isNotEmpty ? driverName : 'Chauffeur inconnu', style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.truck, size: 14, color: _kTextSecondary),
              const SizedBox(width: 6),
              Text('Camion : $truckPlate', style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary)),
            ],
          ),
          
          if (!isCancelled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _kBackground, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fournisseur', style: GoogleFonts.inter(fontSize: 9, color: _kAccent, fontWeight: FontWeight.bold)),
                            Text('$supplierTonnage t', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _kTextPrimary)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reçu', style: GoogleFonts.inter(fontSize: 10, color: _kTextSecondary)),
                            Text('$receivedTonnage t', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (supplierTonnage != 'N/A' && receivedTonnage != 'N/A') ...[
                        (() {
                          final s = double.tryParse(supplierTonnage) ?? 0.0;
                          final r = double.tryParse(receivedTonnage) ?? 0.0;
                          final diff = s - r;
                          if (diff > 0.01) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Manque', style: GoogleFonts.inter(fontSize: 9, color: _kDanger, fontWeight: FontWeight.bold)),
                                  Text('${(diff * 1000).round()}kg', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: _kDanger)),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        })(),
                      ],
                      if (photoUrl != null && photoUrl.toString() != 'null' && photoUrl.isNotEmpty)
                        IconButton(
                          onPressed: () => _showProofImage(context, photoUrl),
                          icon: const Icon(LucideIcons.image, color: _kPrimary, size: 20),
                          tooltip: 'Voir Bon',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            backgroundColor: _kPrimary.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          const Divider(height: 24, color: Colors.white12),
          
          if (!isReceived && !isCancelled) ...[
            Text(
              'Montant Revenu / Bonus (TND)',
              style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _revenueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kBackground,
                hintText: 'Ex: 150.0',
                hintStyle: TextStyle(color: _kTextSecondary.withValues(alpha: 0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Action Buttons
          isReceived
              ? Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hasProblem ? LucideIcons.alertCircle : LucideIcons.checkCircle2, color: hasProblem ? Colors.orange : _kAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          hasProblem ? 'Reçu avec signalement' : 'Documents reçus et archivés', 
                          style: GoogleFonts.inter(color: hasProblem ? Colors.orange : _kAccent, fontWeight: FontWeight.w600)
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.trip['revenue'] != null)
                          Text(
                            'Revenu : ${widget.trip['revenue']} TND',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                          )
                        else
                          Text(
                            'Revenu non défini',
                            style: GoogleFonts.poppins(fontSize: 14, color: _kTextSecondary),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(LucideIcons.edit3, size: 16, color: Colors.orangeAccent),
                          onPressed: _isLoading ? null : _editRevenue,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: 'Modifier revenu',
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _markAsReceived,
                        icon: _isLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Icon(LucideIcons.checkCircle),
                        label: const Text('Marquer Reçu'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kWarning,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _isLoading ? null : _reportProblem,
                      icon: const Icon(LucideIcons.alertTriangle, color: _kDanger),
                      tooltip: 'Signaler un problème',
                      style: IconButton.styleFrom(
                        backgroundColor: _kDanger.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _kDanger.withValues(alpha: 0.3))),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
