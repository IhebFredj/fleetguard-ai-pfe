import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fleetguard/providers/obd_remote_provider.dart';
import '../services/fleet_ai_engine.dart';

class OBDRemoteScreen extends ConsumerWidget {
  final String camionId;
  final String plate;
  const OBDRemoteScreen({super.key, required this.camionId, required this.plate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerKey = '$camionId|$plate';
    final state = ref.watch(obdRemoteProvider(providerKey));

    const bg = Color(0xFF0F1923);
    const cardBg = Color(0xFF1A2636);
    const primary = Color(0xFF00BCD4);
    const accent = Color(0xFF26C6DA);
    const softWhite = Color(0xFFF0F4F8);
    const dimWhite = Color(0xFF8899AA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF152232),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: primary.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cell_tower, color: primary, size: 16),
                  SizedBox(width: 4),
                  Text('REMOTE', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text('Suivi à distance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(obdRemoteProvider(providerKey).notifier).refresh(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Camion $plate', style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ),
      body: state.isLoading && state.lastUpdate == null
          ? const Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              color: primary,
              onRefresh: () => ref.read(obdRemoteProvider(providerKey).notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _statusBanner(state, primary, accent, dimWhite),
                  const SizedBox(height: 14),
                  _EngineStatusWidget(
                    rpm: state.data.rpm,
                    speed: state.data.vitesse,
                    isOnline: state.lastUpdate != null &&
                        DateTime.now().difference(state.lastUpdate!).inMinutes < 2,
                  ),
                  const SizedBox(height: 14),
                  _fatigueCard(state.data, cardBg, softWhite),
                  const SizedBox(height: 12),
                  _engineCard(state.data, cardBg, softWhite),
                  const SizedBox(height: 12),
                  _fuelCard(state.data, cardBg, softWhite),
                  const SizedBox(height: 12),
                  _driveCard(state.data, cardBg, softWhite),
                  const SizedBox(height: 12),
                  _electricEnvCard(state.data, cardBg, softWhite),
                  const SizedBox(height: 12),
                  _diagnosticCard(state.data, cardBg, softWhite),
                  const SizedBox(height: 12),
                  if (state.data.protocol == 'J1939' ||
                      state.data.turboPressureKpa != null ||
                      state.data.adBlueLevelPct != null ||
                      state.data.gearCurrent != null)
                    _heavyTruckCard(state.data, cardBg, softWhite),
                  if (state.data.protocol == 'J1939' ||
                      state.data.turboPressureKpa != null ||
                      state.data.adBlueLevelPct != null ||
                      state.data.gearCurrent != null)
                    const SizedBox(height: 12),
                  if (state.history.length > 2) _chartsCard(state.history, cardBg),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ─── STATUS BANNER ───

  Widget _statusBanner(OBDRemoteState state, Color primary, Color accent, Color dimWhite) {
    final isOnline = state.lastUpdate != null &&
        DateTime.now().difference(state.lastUpdate!).inMinutes < 2;
    final statusColor = isOnline ? const Color(0xFF00E676) : const Color(0xFFFF9800);
    final statusText = isOnline ? 'EN LIGNE' : 'HORS LIGNE';
    final ago = state.lastUpdate != null
        ? _timeAgo(DateTime.now().difference(state.lastUpdate!))
        : 'jamais';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.08),
            statusColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Pulsing indicator
          _PulsingDot(color: statusColor, isLive: isOnline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text('Dernière mise à jour : $ago',
                    style: TextStyle(color: dimWhite, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_outlined, color: primary, size: 16),
                const SizedBox(width: 4),
                Text('Supabase', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI FATIGUE CARD ───

  Widget _fatigueCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    int harshBrakes = (d.vitesse > 50 && d.rpm < 1000) ? 1 : 0;
    int overspeed = (d.vitesse > 90) ? 1 : 0;
    double duration = (d.runTimeSec ?? 0) / 3600.0;
    double hour = DateTime.now().hour + (DateTime.now().minute / 60.0);

    final ai = FleetAiEngine().analyzeComplete(
      durationHours: duration,
      hourOfDay: hour,
      rpm: d.rpm,
      speed: d.vitesse,
      temperature: d.temperature,
      fuelPct: d.carburant,
      oilPressure: d.pressionHuileBar,
      consoL100: d.consoL100,
      brakeCount: harshBrakes,
      overspeedCount: overspeed,
      dtcCount: d.dtcCount,
      milOn: d.milOn,
      batteryVoltage: d.batteryVoltage,
      engineLoadPct: d.engineLoadPct,
      oilTempC: d.oilTempC,
      ambientTempC: d.ambientTempC,
      camion: d.camion,
    );

    final fatigueColor = ai.fatigueRisk > 0.7
        ? Colors.redAccent
        : (ai.fatigueRisk > 0.4 ? Colors.orangeAccent : Colors.greenAccent);
    final drivingColor = ai.drivingRisk > 0.7
        ? Colors.redAccent
        : (ai.drivingRisk > 0.4 ? Colors.orangeAccent : Colors.greenAccent);
    final engineColor = ai.engineHealth > 0.7
        ? Colors.greenAccent
        : (ai.engineHealth > 0.4 ? Colors.orangeAccent : Colors.redAccent);
    final ecoColor = ai.ecoScore > 70
        ? Colors.greenAccent
        : (ai.ecoScore > 40 ? Colors.orangeAccent : Colors.redAccent);

    return _card(
      cardBg: cardBg,
      icon: Icons.psychology,
      iconColor: const Color(0xFF00E5FF),
      title: 'Intelligence Artificielle',
      titleBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('AI Engine v2',
            style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      ),
      children: [
        // ── Fatigue ──
        _gauge('Fatigue Chauffeur',
            '${(ai.fatigueRisk * 100).toStringAsFixed(0)}', '%',
            ai.fatigueRisk, fatigueColor),
        _statRow(Icons.airline_seat_recline_normal, 'État',
            ai.fatigueLevel, fatigueColor),
        const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),

        // ── Risque de conduite ──
        _gauge('Risque Conduite',
            '${(ai.drivingRisk * 100).toStringAsFixed(0)}', '%',
            ai.drivingRisk, drivingColor),
        _statRow(Icons.shield_outlined, 'Statut',
            ai.drivingLevel, drivingColor),
        const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),

        // ── Santé moteur ──
        _gauge('Santé Moteur',
            '${(ai.engineHealth * 100).toStringAsFixed(0)}', '%',
            ai.engineHealth, engineColor),
        _statRow(Icons.build_circle_outlined, 'Diagnostic',
            ai.engineLevel, engineColor),
        const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),

        // ── Éco-score ──
        _gauge('Éco-Conduite',
            '${ai.ecoScore.toStringAsFixed(0)}', '/100',
            ai.ecoScore / 100.0, ecoColor),

        // ── Vol de carburant ──
        if (ai.fuelTheftRisk > 0.1)
          _statRow(Icons.local_gas_station, '⚠ Anomalie Carburant',
              '${(ai.fuelTheftRisk * 100).toStringAsFixed(0)}% suspicion',
              Colors.redAccent),

        // ── Alertes générées ──
        if (ai.alerts.isNotEmpty) ...[
          const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),
          ...ai.alerts.map((alert) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                  ),
                  child: Text(alert,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ),
              )),
        ],
      ],
    );
  }

  // ─── ENGINE CARD ───

  Widget _engineCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    final rpmColor = d.rpm > 4000 ? Colors.redAccent : (d.rpm > 2500 ? Colors.orangeAccent : Colors.cyanAccent);
    final tempColor = d.temperature > 100 ? Colors.redAccent : (d.temperature > 90 ? Colors.orangeAccent : Colors.greenAccent);

    return _card(
      cardBg: cardBg,
      icon: Icons.settings_suggest,
      iconColor: Colors.cyanAccent,
      title: 'Moteur',
      children: [
        _gauge('RPM', '${d.rpm}', 'tr/min', d.rpm / 6000, rpmColor),
        _gauge('Vitesse', '${d.vitesse}', 'km/h', d.vitesse / 180, Colors.lightBlueAccent),
        _statRow(Icons.thermostat, 'Température', '${d.temperature} °C', tempColor),
        if (d.engineLoadPct != null)
          _statRow(Icons.speed, 'Charge moteur', '${d.engineLoadPct!.toStringAsFixed(1)} %', Colors.tealAccent),
        _statRow(Icons.oil_barrel_outlined, 'Pression huile', '${d.pressionHuileBar.toStringAsFixed(1)} bar', Colors.amberAccent),
        if (d.oilTempC != null)
          _statRow(Icons.local_fire_department, 'Temp. huile', '${d.oilTempC!.toStringAsFixed(0)} °C', Colors.deepOrangeAccent),
        if (d.pedalPct != null)
          _statRow(Icons.touch_app, 'Pédale', '${d.pedalPct!.toStringAsFixed(0)} %', Colors.blueAccent),
      ],
    );
  }

  // ─── FUEL CARD ───

  Widget _fuelCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    final fuelColor = d.carburant > 20 ? Colors.greenAccent : (d.carburant > 10 ? Colors.orangeAccent : Colors.redAccent);
    final isIdle = d.vitesse < 3;
    final consoLabel = isIdle ? 'Conso. au ralenti' : 'Consommation';
    final consoValue = isIdle
        ? '${(d.fuelRateLh ?? d.consoL100).toStringAsFixed(1)} L/h'
        : '${d.consoL100.toStringAsFixed(1)} L/100km';

    return _card(
      cardBg: cardBg,
      icon: Icons.local_gas_station,
      iconColor: fuelColor,
      title: 'Carburant',
      children: [
        _gauge('Niveau', '${d.carburant}', '%', d.carburant / 100, fuelColor),
        _statRow(Icons.autorenew, consoLabel, consoValue, Colors.pinkAccent),
        _statRow(Icons.place_outlined, 'Distance (session)', '${d.distanceKm.toStringAsFixed(2)} km', Colors.purpleAccent),
        if (d.fuelRateLh != null)
          _statRow(Icons.water_drop, 'Débit', '${d.fuelRateLh!.toStringAsFixed(2)} L/h', Colors.cyanAccent),
        _statRow(Icons.summarize_outlined, 'Consommé (session)', '${d.fuelConsumedTotalL.toStringAsFixed(3)} L', Colors.orangeAccent),
        if (d.fuelPressureKpa != null)
          _statRow(Icons.compress, 'Pression carburant', '${d.fuelPressureKpa!.toStringAsFixed(0)} kPa', Colors.lightGreenAccent),
        if (d.fuelRailKpa != null)
          _statRow(Icons.settings_input_component, 'Pression rampe', '${(d.fuelRailKpa! / 100).toStringAsFixed(1)} bar', Colors.limeAccent),
        if (d.fuelTempC != null)
          _statRow(Icons.thermostat_auto, 'Temp. carburant', '${d.fuelTempC!.toStringAsFixed(0)} °C', Colors.orangeAccent),
        if (d.fuelType != null)
          _statRow(Icons.local_gas_station_outlined, 'Type', d.fuelType!, Colors.white70),
      ],
    );
  }

  // ─── DRIVE / AIR CARD ───

  Widget _driveCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    final hasData = d.iatC != null || d.mapKpa != null || d.tpsPct != null || d.mafGps != null;
    if (!hasData && d.runTimeSec == null) return const SizedBox.shrink();

    return _card(
      cardBg: cardBg,
      icon: Icons.assessment_outlined,
      iconColor: Colors.amberAccent,
      title: 'Conduite',
      children: [
        if (d.iatC != null)
          _statRow(Icons.air, 'Temp. air admission', '${d.iatC!.toStringAsFixed(0)} °C', Colors.lightBlueAccent),
        if (d.mapKpa != null)
          _statRow(Icons.compress_rounded, 'Pression admission', '${d.mapKpa!.toStringAsFixed(0)} kPa', Colors.amberAccent),
        if (d.tpsPct != null)
          _statRow(Icons.tune, 'Papillon (TPS)', '${d.tpsPct!.toStringAsFixed(0)} %', Colors.tealAccent),
        if (d.mafGps != null)
          _statRow(Icons.air_outlined, 'Débit air (MAF)', '${d.mafGps!.toStringAsFixed(1)} g/s', Colors.cyanAccent),
        if (d.runTimeSec != null)
          _statRow(Icons.timer_outlined, 'Temps moteur', _formatDuration(d.runTimeSec!), Colors.white70),
        if (d.distSinceDtcKm != null)
          _statRow(Icons.refresh_outlined, 'Dist. depuis reset DTC', '${d.distSinceDtcKm} km', Colors.white70),
      ],
    );
  }

  // ─── ELECTRIC & ENVIRONMENT ───

  Widget _electricEnvCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    if (d.batteryVoltage == null && d.ambientTempC == null && d.baroKpa == null) {
      return const SizedBox.shrink();
    }
    return _card(
      cardBg: cardBg,
      icon: Icons.bolt,
      iconColor: Colors.yellowAccent,
      title: 'Électrique & Environnement',
      children: [
        if (d.batteryVoltage != null)
          _statRow(Icons.battery_charging_full, 'Tension batterie', '${d.batteryVoltage!.toStringAsFixed(2)} V', Colors.yellowAccent),
        if (d.ambientTempC != null)
          _statRow(Icons.thermostat_outlined, 'Temp. extérieure', '${d.ambientTempC!.toStringAsFixed(0)} °C', Colors.lightBlueAccent),
        if (d.baroKpa != null)
          _statRow(Icons.compress_rounded, 'Pression baro.', '${d.baroKpa!.toStringAsFixed(0)} kPa', Colors.grey),
      ],
    );
  }

  // ─── DIAGNOSTIC ───

  Widget _diagnosticCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    final hasDtc = d.milOn || d.dtcCount > 0;
    final confirmedCodes = (d.dtcCodes != null && d.dtcCodes!.isNotEmpty)
        ? d.dtcCodes!.split(',')
        : <String>[];
    final pendingCodes = (d.dtcPending != null && d.dtcPending!.isNotEmpty)
        ? d.dtcPending!.split(',')
        : <String>[];

    return _card(
      cardBg: cardBg,
      icon: Icons.medical_information_outlined,
      iconColor: hasDtc ? Colors.redAccent : Colors.greenAccent,
      title: 'Diagnostic',
      children: [
        // MIL Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                hasDtc ? Icons.warning_amber_rounded : Icons.check_circle,
                color: hasDtc ? Colors.redAccent : Colors.greenAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDtc ? 'Anomalie détectée !' : 'Moteur OK — Aucune anomalie',
                      style: TextStyle(
                        color: hasDtc ? Colors.redAccent : Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (hasDtc)
                      Text(
                        'Voyant MIL : ${d.milOn ? "ALLUMÉ" : "éteint"} · ${d.dtcCount} code${d.dtcCount > 1 ? "s" : ""}',
                        style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Confirmed DTCs
        if (confirmedCodes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Codes défaut confirmés',
                style: TextStyle(color: Color(0xFF8899AA), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: confirmedCodes.map((code) => _dtcBadge(code.trim(), Colors.redAccent)).toList(),
            ),
          ),
        ],

        // Pending DTCs
        if (pendingCodes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('Codes en attente (intermittents)',
                style: TextStyle(color: Color(0xFF8899AA), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: pendingCodes.map((code) => _dtcBadge(code.trim(), Colors.orangeAccent)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dtcBadge(String code, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: color, size: 14),
          const SizedBox(width: 4),
          Text(code,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }

  // ─── POIDS LOURD (J1939) ───

  Widget _heavyTruckCard(OBDRemoteData d, Color cardBg, Color softWhite) {
    // Rapport de boîte
    String gearLabel = '?';
    Color gearColor = Colors.white70;
    if (d.gearCurrent != null) {
      if (d.gearCurrent! == -1) { gearLabel = 'R'; gearColor = Colors.orangeAccent; }
      else if (d.gearCurrent! == 0) { gearLabel = 'N'; gearColor = Colors.yellowAccent; }
      else { gearLabel = '${d.gearCurrent}'; gearColor = Colors.greenAccent; }
    }

    // AdBlue
    Color adBlueColor = Colors.cyanAccent;
    if (d.adBlueLevelPct != null) {
      if (d.adBlueLevelPct! < 5) adBlueColor = Colors.redAccent;
      else if (d.adBlueLevelPct! < 15) adBlueColor = Colors.orangeAccent;
    }

    // Température échappement
    Color exhaustColor = Colors.deepOrangeAccent;
    if (d.exhaustTempC != null && d.exhaustTempC! > 700) exhaustColor = Colors.redAccent;

    // Turbo
    Color turboColor = Colors.lightBlueAccent;
    if (d.turboPressureKpa != null && d.turboPressureKpa! > 200) turboColor = Colors.greenAccent;

    return _card(
      cardBg: cardBg,
      icon: Icons.local_shipping_rounded,
      iconColor: const Color(0xFFFFD54F),
      title: 'Poids Lourd — J1939',
      titleBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD54F).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.4)),
        ),
        child: const Text('SAE J1939',
            style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.bold)),
      ),
      children: [
        // ── Rapport de boîte ──
        if (d.gearCurrent != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.settings_input_component_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 10),
                const Text('Rapport de boîte', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: gearColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: gearColor.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(gearLabel,
                        style: TextStyle(color: gearColor, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),

        // ── Couple moteur ──
        if (d.torquePct != null) ...[
          _gauge('Couple moteur', '${d.torquePct!.toStringAsFixed(0)}', '%',
              (d.torquePct! / 100.0).clamp(0.0, 1.0), Colors.amberAccent),
        ],

        // ── Turbo ──
        if (d.turboPressureKpa != null)
          _statRow(Icons.air, 'Pression turbo',
              '${d.turboPressureKpa!.toStringAsFixed(0)} kPa', turboColor),

        // ── Température échappement ──
        if (d.exhaustTempC != null)
          _statRow(Icons.local_fire_department_outlined, 'Temp. échappement',
              '${d.exhaustTempC!.toStringAsFixed(0)} °C', exhaustColor),

        const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),

        // ── AdBlue ──
        if (d.adBlueLevelPct != null) ...[
          _gauge('Niveau AdBlue / DEF', '${d.adBlueLevelPct}', '%',
              (d.adBlueLevelPct! / 100.0).clamp(0.0, 1.0), adBlueColor),
          if (d.adBlueLevelPct! < 10)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('⚠ Niveau AdBlue CRITIQUE — Risque de dépotage moteur',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
        ],

        // ── Niveau liquide refroidissement ──
        if (d.coolantLevelPct != null)
          _statRow(Icons.water_drop_outlined, 'Liquide refroidissement',
              '${d.coolantLevelPct!.toStringAsFixed(0)} %',
              d.coolantLevelPct! < 30 ? Colors.redAccent : Colors.cyanAccent),

        const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),

        // ── Retarder ──
        if (d.retarderPct != null && d.retarderPct! > 0)
          _statRow(Icons.speed_outlined, 'Ralentisseur actif',
              '${d.retarderPct!.toStringAsFixed(0)} %', Colors.purpleAccent),

        // ── Odomètre ──
        if (d.odometerKm != null)
          _statRow(Icons.route_outlined, 'Odomètre total',
              '${(d.odometerKm! / 1000).toStringAsFixed(1)} ×10³ km', Colors.white70),

        // ── Heures moteur (calculées depuis run_time_sec ÷ 3600) ──
        if (d.runTimeSec != null && d.runTimeSec! > 3600)
          _statRow(Icons.av_timer_outlined, 'Heures moteur',
              '${(d.runTimeSec! / 3600).toStringAsFixed(0)} h (session)',
              Colors.white54),

        // ── Consommation totale ──
        if (d.fuelTotalL != null)
          _statRow(Icons.local_gas_station_outlined, 'Conso. totale (usine)',
              '${(d.fuelTotalL! / 1000).toStringAsFixed(1)} m³ (${d.fuelTotalL!.toStringAsFixed(0)} L)',
              Colors.orangeAccent),
      ],
    );
  }

  // ─── CHARTS ───


  Widget _chartsCard(List<OBDRemoteData> history, Color cardBg) {
    final rpmSpots = <FlSpot>[];
    final speedSpots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      rpmSpots.add(FlSpot(i.toDouble(), history[i].rpm.toDouble()));
      speedSpots.add(FlSpot(i.toDouble(), history[i].vitesse.toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              const Text('Historique temps réel',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Text('${history.length} pts', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _legendDot(Colors.cyanAccent, 'RPM'),
              const SizedBox(width: 16),
              _legendDot(Colors.amberAccent, 'Vitesse (km/h)'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: rpmSpots,
                    isCurved: true,
                    color: Colors.cyanAccent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.05)),
                  ),
                  LineChartBarData(
                    spots: speedSpots,
                    isCurved: true,
                    color: Colors.amberAccent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.amberAccent.withOpacity(0.05)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── REUSABLE WIDGETS ───

  Widget _card({
    required Color cardBg,
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? titleBadge,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                if (titleBadge != null) ...[
                  const SizedBox(width: 8),
                  titleBadge,
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13))),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gauge(String label, String value, String unit, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' $unit', style: const TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
                  ]),
                  key: ValueKey(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  // ─── HELPERS ───

  String _timeAgo(Duration d) {
    if (d.inSeconds < 5) return 'à l\'instant';
    if (d.inSeconds < 60) return 'il y a ${d.inSeconds}s';
    if (d.inMinutes < 60) return 'il y a ${d.inMinutes}min';
    if (d.inHours < 24) return 'il y a ${d.inHours}h';
    return 'il y a ${d.inDays}j';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

// ─── PULSING DOT ANIMATION ───

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool isLive;
  const _PulsingDot({required this.color, required this.isLive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) {
      return Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: widget.color.withOpacity(0.4), shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.5 + 0.5 * _ctrl.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.3 * _ctrl.value),
              blurRadius: 8 * _ctrl.value,
              spreadRadius: 2 * _ctrl.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ENGINE STATUS ANIMATED WIDGET ───

enum _EngineState { stopped, contactOn, idle, running }

class _EngineStatusWidget extends StatefulWidget {
  final int rpm;
  final int speed;
  final bool isOnline;
  const _EngineStatusWidget({required this.rpm, required this.speed, required this.isOnline});

  @override
  State<_EngineStatusWidget> createState() => _EngineStatusWidgetState();
}

class _EngineStatusWidgetState extends State<_EngineStatusWidget> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  _EngineState get _state {
    if (!widget.isOnline) return _EngineState.stopped;
    if (widget.rpm > 600 && widget.speed > 3) return _EngineState.running;
    if (widget.rpm > 0) return _EngineState.idle;
    return _EngineState.contactOn;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    final Color color;
    final String label;
    final String subtitle;
    final IconData icon;

    switch (state) {
      case _EngineState.running:
        color = const Color(0xFF00E676);
        label = 'EN MARCHE';
        subtitle = '${widget.rpm} tr/min · ${widget.speed} km/h';
        icon = Icons.directions_car;
      case _EngineState.idle:
        color = const Color(0xFF00BCD4);
        label = 'AU RALENTI';
        subtitle = '${widget.rpm} tr/min · Véhicule arrêté';
        icon = Icons.hourglass_bottom_rounded;
      case _EngineState.contactOn:
        color = const Color(0xFFFF9800);
        label = 'CONTACT ON';
        subtitle = 'Moteur éteint · Clé sur contact';
        icon = Icons.key;
      case _EngineState.stopped:
        color = const Color(0xFF78909C);
        label = 'ARRÊTÉ';
        subtitle = 'Aucune donnée récente';
        icon = Icons.power_settings_new;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _waveCtrl]),
      builder: (_, __) {
        final pulseVal = _pulseCtrl.value;
        final waveVal = _waveCtrl.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.06 + 0.04 * pulseVal),
                const Color(0xFF1A2636),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15 + 0.1 * pulseVal)),
          ),
          child: Row(
            children: [
              // Animated engine icon with glow rings
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer wave ring (only when running or idle)
                    if (state == _EngineState.running || state == _EngineState.idle)
                      Container(
                        width: 56 + 4 * waveVal,
                        height: 56 + 4 * waveVal,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withOpacity(0.15 * (1 - waveVal)),
                            width: 1.5,
                          ),
                        ),
                      ),
                    // Middle pulse ring
                    Container(
                      width: 48 + 4 * pulseVal,
                      height: 48 + 4 * pulseVal,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.08 + 0.06 * pulseVal),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2 * pulseVal),
                            blurRadius: 12 * pulseVal,
                            spreadRadius: 2 * pulseVal,
                          ),
                        ],
                      ),
                    ),
                    // Inner circle with icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.15),
                        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8899AA),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // RPM mini gauge (only if engine is on)
              if (state == _EngineState.running || state == _EngineState.idle)
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (widget.rpm / 5000).clamp(0.0, 1.0),
                        strokeWidth: 4,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(color.withOpacity(0.6 + 0.4 * pulseVal)),
                      ),
                      Text(
                        '${(widget.rpm / 1000).toStringAsFixed(1)}k',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
