import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fleetguard/providers/obd_provider.dart';

class OBDLiveScreen extends ConsumerStatefulWidget {
  final String camionId;
  final String plate;
  const OBDLiveScreen({super.key, required this.camionId, required this.plate});

  @override
  ConsumerState<OBDLiveScreen> createState() => _OBDLiveScreenState();
}

class _OBDLiveScreenState extends ConsumerState<OBDLiveScreen> {
  String? _selectedAddress;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(obdProvider);
    final ctrl = ref.read(obdProvider.notifier);

    final bg = const Color(0xFF1C1C1C);
    final primary = const Color(0xFF1D5D9B);
    final softWhite = const Color(0xFFF4F4F4);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text('Suivi moteur en temps réel'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  state.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isConnected ? 'Connecté' : 'Déconnecté',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Camion ${widget.plate}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _connectionControls(context, state, ctrl, primary, softWhite),
            const SizedBox(height: 12),
            _engineCard(state, softWhite),
            const SizedBox(height: 12),
            _fuelCard(state, softWhite),
            const SizedBox(height: 12),
            _driveCard(state, softWhite),
            const SizedBox(height: 12),
            _odometerCard(state, softWhite),
            const SizedBox(height: 12),
            _diagnosticCard(state, ctrl, softWhite),
            const SizedBox(height: 12),
            _charts(state, softWhite),
            const SizedBox(height: 16),
            _bottomActions(state, ctrl, primary),
          ],
        ),
      ),
    );
  }

  Widget _connectionControls(
    BuildContext context,
    OBDState state,
    OBDController ctrl,
    Color primary,
    Color softWhite,
  ) {
    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth, color: Colors.lightBlueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bluetooth OBD2',
                    style: TextStyle(
                      color: softWhite,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                FilledButton.icon(
                  onPressed: state.isScanning
                      ? null
                      : state.isConnected
                      ? () => ctrl.disconnect()
                      : () async {
                          const String myObdAddress =
                              'classic:00:10:CC:4F:36:03';
                          // ignore: avoid_print
                          print('>>> Clic Connecter - adresse : $myObdAddress');
                          await ref
                              .read(obdProvider.notifier)
                              .connectTo(myObdAddress);
                        },
                  icon: state.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(state.isConnected ? Icons.link_off : Icons.link),
                  label: Text(
                    state.isScanning
                        ? 'Veuillez patienter'
                        : (state.isConnected ? 'Déconnecter' : 'Connecter'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (state.isScanning) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (state.statusMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.statusMessage,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Text(
          value,
          key: ValueKey(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _engineCard(OBDState state, Color softWhite) {
    final d = state.data;
    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Moteur',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(Icons.settings, color: softWhite),
          ),
          _statTile(
            label: 'RPM moteur',
            value: '${d.rpm} tr/min',
            icon: Icons.settings_suggest,
            color: Colors.cyanAccent,
          ),
          _statTile(
            label: 'Température moteur',
            value: '${d.engineTempC.toStringAsFixed(0)} °C',
            icon: Icons.thermostat,
            color: Colors.orangeAccent,
          ),
          _statTile(
            label: 'Vitesse',
            value: '${d.speedKmh.toStringAsFixed(0)} km/h',
            icon: Icons.directions_car,
            color: Colors.lightBlueAccent,
          ),
          _statTile(
            label: 'Pression huile',
            value: '${d.oilPressureBar.toStringAsFixed(1)} bar',
            icon: Icons.oil_barrel_outlined,
            color: Colors.amberAccent,
          ),
          if (d.engineLoadPct != null)
            _statTile(
              label: 'Charge moteur',
              value: '${d.engineLoadPct!.toStringAsFixed(0)} %',
              icon: Icons.speed,
              color: Colors.tealAccent,
            ),
          if (d.oilTempC != null)
            _statTile(
              label: 'Température huile',
              value: '${d.oilTempC!.toStringAsFixed(0)} °C',
              icon: Icons.local_fire_department,
              color: Colors.deepOrangeAccent,
            ),
        ],
      ),
    );
  }

  Widget _fuelCard(OBDState state, Color softWhite) {
    final d = state.data;
    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Carburant',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(Icons.local_gas_station, color: softWhite),
          ),
          _statTile(
            label: 'Niveau carburant',
            value: d.fuelLevelPercent != null
                ? '${d.fuelLevelPercent} %'
                : 'N/A',
            icon: Icons.local_gas_station,
            color: Colors.greenAccent,
          ),
          _statTile(
            label: 'Consommation instantanée',
            value: '${d.instantConsumptionLPer100.toStringAsFixed(1)} L/100km',
            icon: Icons.autorenew,
            color: Colors.pinkAccent,
          ),
          _statTile(
            label: 'Distance parcourue',
            value: '${d.distanceKm.toStringAsFixed(1)} km',
            icon: Icons.place_outlined,
            color: Colors.purpleAccent,
          ),
          if (d.fuelPressureKpa != null)
            _statTile(
              label: 'Pression carburant',
              value: '${d.fuelPressureKpa!.toStringAsFixed(0)} kPa',
              icon: Icons.compress,
              color: Colors.lightGreenAccent,
            ),
          if (d.fuelTempC != null)
            _statTile(
              label: 'Température carburant',
              value: '${d.fuelTempC!.toStringAsFixed(0)} °C',
              icon: Icons.thermostat_auto,
              color: Colors.orangeAccent,
            ),
          if (d.fuelRateLh != null)
            _statTile(
              label: 'Débit carburant',
              value: '${d.fuelRateLh!.toStringAsFixed(1)} L/h',
              icon: Icons.water_drop,
              color: Colors.cyanAccent,
            ),
          if (d.fuelType != null)
            _statTile(
              label: 'Type de carburant',
              value: d.fuelType!,
              icon: Icons.local_gas_station_outlined,
              color: Colors.white70,
            ),
        ],
      ),
    );
  }

  Widget _driveCard(OBDState state, Color softWhite) {
    final d = state.data;
    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Conduite',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(Icons.assessment_outlined, color: softWhite),
          ),
          if (d.iatC != null)
            _statTile(
              label: 'Temp. air admission (IAT)',
              value: '${d.iatC!.toStringAsFixed(0)} °C',
              icon: Icons.air,
              color: Colors.lightBlueAccent,
            ),
          if (d.mapKpa != null)
            _statTile(
              label: 'Pression admission (MAP)',
              value: '${d.mapKpa!.toStringAsFixed(0)} kPa',
              icon: Icons.compress_rounded,
              color: Colors.amberAccent,
            ),
          if (d.tpsPct != null)
            _statTile(
              label: 'Angle papillon (TPS)',
              value: '${d.tpsPct!.toStringAsFixed(0)} %',
              icon: Icons.tune,
              color: Colors.tealAccent,
            ),
          if (d.runTimeSec != null)
            _statTile(
              label: 'Temps depuis démarrage',
              value: '${d.runTimeSec} s',
              icon: Icons.timer_outlined,
              color: Colors.white70,
            ),
          if (d.distanceSinceDtcKm != null)
            _statTile(
              label: 'Distance depuis reset DTC',
              value: '${d.distanceSinceDtcKm} km',
              icon: Icons.refresh_outlined,
              color: Colors.white70,
            ),
          if (d.mafGps != null)
            _statTile(
              label: 'Débit air (MAF)',
              value: '${d.mafGps!.toStringAsFixed(1)} g/s',
              icon: Icons.air_outlined,
              color: Colors.cyanAccent,
            ),
        ],
      ),
    );
  }

  Widget _odometerCard(OBDState state, Color softWhite) {
    final d = state.data;
    if (d.odometerKm == null) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Odomètre',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(Icons.av_timer, color: softWhite),
          ),
          _statTile(
            label: 'Kilométrage total',
            value: '${d.odometerKm!.toStringAsFixed(0)} km',
            icon: Icons.directions_car_filled,
            color: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _diagnosticCard(OBDState state, OBDController ctrl, Color softWhite) {
    final d = state.data;
    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text(
              'Diagnostic',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(
              Icons.medical_information_outlined,
              color: softWhite,
            ),
          ),
          ListTile(
            leading: Icon(
              d.engineOk ? Icons.check_circle : Icons.error,
              color: d.engineOk ? Colors.lightGreenAccent : Colors.redAccent,
            ),
            title: Text(
              d.engineOk ? 'Statut moteur : OK' : 'Anomalie détectée',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (d.dtcCodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Codes d\'erreur (DTC):',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  for (final c in d.dtcCodes)
                    Text('• $c', style: const TextStyle(color: Colors.white)),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Aucun code d\'erreur',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => ctrl.clearDTC(),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Effacer les erreurs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _charts(OBDState state, Color softWhite) {
    if (state.rpmSeries.isEmpty && state.speedSeries.isEmpty) {
      return const SizedBox.shrink();
    }
    final t0 = DateTime.now().subtract(const Duration(seconds: 120));
    List<FlSpot> rpmSpots = [
      for (final p in state.rpmSeries)
        FlSpot(p.t.difference(t0).inSeconds.toDouble(), p.v),
    ];
    List<FlSpot> spdSpots = [
      for (final p in state.speedSeries)
        FlSpot(p.t.difference(t0).inSeconds.toDouble(), p.v),
    ];

    return Card(
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Courbes temps réel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: rpmSpots,
                      isCurved: true,
                      color: Colors.cyanAccent,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: spdSpots,
                      isCurved: true,
                      color: Colors.amberAccent,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions(OBDState state, OBDController ctrl, Color primary) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => ctrl.pollOnce(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Lire données'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => ctrl.sendToServer(
              widget.camionId,
              Uri.parse('https://example.com/api/obd/update'),
            ),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Envoyer au serveur'),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => ctrl.startDemo(),
            icon: const Icon(Icons.picture_in_picture_alt),
            label: const Text('Mode démo'),
          ),
        ),
      ],
    );
  }
}
