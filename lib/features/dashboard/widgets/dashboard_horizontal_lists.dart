import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/dashboard_theme.dart';
import '../models/dashboard_models.dart';

class TrucksHorizontalList extends StatelessWidget {
  final List<DashboardTruck> trucks;
  final void Function(DashboardTruck)? onTruckTap;

  const TrucksHorizontalList({
    super.key,
    required this.trucks,
    this.onTruckTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Camions actifs',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.text,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: trucks.length,
            itemBuilder: (_, i) {
              final t = trucks[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _TruckCard(truck: t, onTap: () => onTruckTap?.call(t)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TruckCard extends StatelessWidget {
  final DashboardTruck truck;
  final VoidCallback? onTap;

  const _TruckCard({required this.truck, this.onTap});

  static Color _statusColor(TruckStatus s) {
    switch (s) {
      case TruckStatus.active:
        return DashboardTheme.accent;
      case TruckStatus.warning:
        return DashboardTheme.alert;
      case TruckStatus.critical:
        return DashboardTheme.critical;
      case TruckStatus.maintenance:
        return DashboardTheme.textLight;
      case TruckStatus.inactive:
        return DashboardTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(truck.status);
    return Material(
      color: DashboardTheme.background,
      borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: DashboardTheme.border),
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      truck.plate,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DashboardTheme.text,
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                ],
              ),
              if (truck.driverName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Chauffeur: ${truck.driverName!}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: DashboardTheme.textLight,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    LucideIcons.gauge,
                    size: 14,
                    color: DashboardTheme.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${truck.speedKmh?.toStringAsFixed(0) ?? "--"} km/h',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    LucideIcons.thermometer,
                    size: 14,
                    color: DashboardTheme.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${truck.engineTempC?.toStringAsFixed(0) ?? "--"} °C',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Carburant',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: DashboardTheme.textLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (truck.fuelPercent ?? 0) / 100,
                        backgroundColor: DashboardTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(c),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${truck.fuelPercent?.toStringAsFixed(0) ?? "--"}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlertsHorizontalList extends StatelessWidget {
  final List<DashboardAlert> alerts;
  final void Function(DashboardAlert)? onAlertTap;
  final void Function(DashboardAlert)? onMarkRead;

  const AlertsHorizontalList({
    super.key,
    required this.alerts,
    this.onAlertTap,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Alertes en direct',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.text,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: alerts.length,
            itemBuilder: (_, i) {
              final a = alerts[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _AlertCard(
                  alert: a,
                  onTap: () => onAlertTap?.call(a),
                  onMarkRead: () => onMarkRead?.call(a),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final DashboardAlert alert;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;

  const _AlertCard({required this.alert, this.onTap, this.onMarkRead});

  static Color _bgColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return DashboardTheme.cardRed;
      case AlertSeverity.warning:
        return DashboardTheme.cardOrange;
      case AlertSeverity.info:
        return DashboardTheme.cardBlue;
    }
  }

  static IconData _icon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return LucideIcons.alertTriangle;
      case AlertSeverity.warning:
        return LucideIcons.alertCircle;
      case AlertSeverity.info:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(alert.severity);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _icon(alert.severity),
                    size: 20,
                    color: DashboardTheme.text,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.type,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DashboardTheme.text,
                      ),
                    ),
                  ),
                  if (!alert.read)
                    TextButton(
                      onPressed: onMarkRead,
                      child: Text('Lu', style: GoogleFonts.inter(fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                alert.message,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: DashboardTheme.text,
                ),
              ),
              if (alert.valueAndThreshold != null)
                Text(
                  alert.valueAndThreshold!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.text,
                  ),
                ),
              const Spacer(),
              Text(
                alert.truckPlate,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: DashboardTheme.textLight,
                ),
              ),
              Text(
                '${alert.at.hour.toString().padLeft(2, '0')}:${alert.at.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: DashboardTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TripsHorizontalList extends StatelessWidget {
  final List<DashboardTrip> trips;
  final void Function(DashboardTrip)? onTripTap;

  const TripsHorizontalList({super.key, required this.trips, this.onTripTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Voyages en cours',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.text,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: trips.length,
            itemBuilder: (_, i) {
              final t = trips[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _TripCard(trip: t, onTap: () => onTripTap?.call(t)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  final DashboardTrip trip;
  final VoidCallback? onTap;

  const _TripCard({required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardTheme.background,
      borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: DashboardTheme.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.clientName,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.text,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    LucideIcons.mapPin,
                    size: 12,
                    color: DashboardTheme.textLight,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: DashboardTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.driverName} · ${trip.truckPlate}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: DashboardTheme.textLight,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: trip.progressPercent / 100,
                  backgroundColor: DashboardTheme.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    DashboardTheme.primary,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${trip.progressPercent.toStringAsFixed(0)} %',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trip.estimatedTimeRemaining != null)
                    Text(
                      'Restant: ${trip.estimatedTimeRemaining}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: DashboardTheme.textLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                trip.status,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: DashboardTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
