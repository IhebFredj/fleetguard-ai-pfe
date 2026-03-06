import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'theme/dashboard_theme.dart';
import 'models/dashboard_models.dart';
import 'providers/dashboard_providers.dart';
import 'widgets/stat_card.dart';
import 'widgets/dashboard_map_card.dart';
import 'widgets/dashboard_horizontal_lists.dart';
import 'widgets/dashboard_charts.dart';
import 'widgets/quick_actions.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final trucksAsync = ref.watch(dashboardTrucksProvider);
    final alertsAsync = ref.watch(dashboardAlertsProvider);
    final tripsAsync = ref.watch(dashboardTripsProvider);
    final chartDataAsync = ref.watch(dashboardChartDataProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardTrucksProvider);
        ref.invalidate(dashboardAlertsProvider);
        ref.invalidate(dashboardTripsProvider);
        ref.invalidate(dashboardChartDataProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DashboardTheme.s16,
          DashboardTheme.s12,
          DashboardTheme.s16,
          DashboardTheme.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A) KPI cards – 4 colonnes (responsive: 2x2 sur petit écran)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 500;
                if (isNarrow) {
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      StatCard(
                        icon: LucideIcons.truck,
                        value: '${stats.activeTrucks}',
                        label: 'Camions actifs',
                        trend: stats.activeTrucksTrend,
                        backgroundColor: DashboardTheme.cardGreen,
                        iconColor: DashboardTheme.accent,
                      ),
                      StatCard(
                        icon: LucideIcons.navigation,
                        value: '${stats.tripsToday}',
                        label: 'Voyages en cours',
                        trend: stats.tripsTrend,
                        backgroundColor: DashboardTheme.cardBlue,
                        iconColor: DashboardTheme.primary,
                      ),
                      StatCard(
                        icon: LucideIcons.trendingUp,
                        value:
                            '${stats.revenueTodayTnd.toStringAsFixed(0)} TND',
                        label: 'Revenus',
                        trend: stats.revenueTrend,
                        backgroundColor: DashboardTheme.cardOrange,
                        iconColor: DashboardTheme.alert,
                      ),
                      StatCard(
                        icon: LucideIcons.alertTriangle,
                        value: '${stats.activeAlerts}',
                        label: 'Alertes',
                        trend: stats.alertsSummary,
                        backgroundColor: DashboardTheme.cardRed,
                        iconColor: DashboardTheme.critical,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: StatCard(
                          icon: LucideIcons.truck,
                          value: '${stats.activeTrucks}',
                          label: 'Camions actifs',
                          trend: stats.activeTrucksTrend,
                          backgroundColor: DashboardTheme.cardGreen,
                          iconColor: DashboardTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: StatCard(
                          icon: LucideIcons.navigation,
                          value: '${stats.tripsToday}',
                          label: 'Voyages en cours',
                          trend: stats.tripsTrend,
                          backgroundColor: DashboardTheme.cardBlue,
                          iconColor: DashboardTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: StatCard(
                          icon: LucideIcons.trendingUp,
                          value:
                              '${stats.revenueTodayTnd.toStringAsFixed(0)} TND',
                          label: 'Revenus',
                          trend: stats.revenueTrend,
                          backgroundColor: DashboardTheme.cardOrange,
                          iconColor: DashboardTheme.alert,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: StatCard(
                          icon: LucideIcons.alertTriangle,
                          value: '${stats.activeAlerts}',
                          label: 'Alertes',
                          trend: stats.alertsSummary,
                          backgroundColor: DashboardTheme.cardRed,
                          iconColor: DashboardTheme.critical,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // B) Carte Google Maps
            trucksAsync.when(
              data: (trucks) => DashboardMapCard(
                trucks: trucks,
                onTruckTap: (t) => _showTruckBottomSheet(context, t),
              ),
              loading: () => _MapPlaceholder(onTap: null),
              error: (_, __) => _MapPlaceholder(onTap: null),
            ),
            const SizedBox(height: 20),

            // C) Camions actifs
            trucksAsync.when(
              data: (trucks) => TrucksHorizontalList(
                trucks: trucks,
                onTruckTap: (t) => _showTruckBottomSheet(context, t),
              ),
              loading: () => const _SectionShimmer(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Alertes
            alertsAsync.when(
              data: (alerts) => AlertsHorizontalList(
                alerts: alerts,
                onAlertTap: (a) {},
                onMarkRead: (a) {},
              ),
              loading: () => const _SectionShimmer(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Voyages en cours
            tripsAsync.when(
              data: (trips) =>
                  TripsHorizontalList(trips: trips, onTripTap: (_) {}),
              loading: () => const _SectionShimmer(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // D) Graphiques
            chartDataAsync.when(
              data: (data) => DashboardChartsSection(data: data),
              loading: () => const _SectionShimmer(height: 420),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // E) Actions rapides
            const QuickActionsBar(
              onNewTrip: null,
              onFuel: null,
              onReport: null,
              onExport: null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showTruckBottomSheet(BuildContext context, DashboardTruck truck) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DashboardTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                truck.plate,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.text,
                ),
              ),
              if (truck.driverName != null)
                Text(
                  'Chauffeur: ${truck.driverName}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: DashboardTheme.textLight,
                  ),
                ),
              const SizedBox(height: 12),
              _detailRow(
                'Vitesse',
                '${truck.speedKmh?.toStringAsFixed(0) ?? "--"} km/h',
              ),
              _detailRow(
                'Temp. moteur',
                '${truck.engineTempC?.toStringAsFixed(0) ?? "--"} °C',
              ),
              _detailRow(
                'Carburant',
                '${truck.fuelPercent?.toStringAsFixed(0) ?? "--"} %',
              ),
              const SizedBox(height: 16),
              Text(
                'Historique OBD2 et GPS disponibles depuis l’écran détail camion.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: DashboardTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: DashboardTheme.textLight,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final VoidCallback? onTap;

  const _MapPlaceholder({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: DashboardTheme.backgroundLight,
          borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
          border: Border.all(color: DashboardTheme.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.map, size: 48, color: DashboardTheme.textLight),
              const SizedBox(height: 8),
              Text(
                'Carte des camions',
                style: GoogleFonts.inter(
                  fontSize: 14,
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

class _SectionShimmer extends StatelessWidget {
  final double height;

  const _SectionShimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: DashboardTheme.backgroundLight,
        borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
