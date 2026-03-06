import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/dashboard_theme.dart';
import '../providers/dashboard_providers.dart';

class DashboardChartsSection extends StatelessWidget {
  final DashboardChartData data;

  const DashboardChartsSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Graphiques',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _TripsBarChart(data: data)),
            const SizedBox(width: 12),
            Expanded(child: _RevenueAreaChart(data: data)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _StatusPieChart(data: data)),
            const SizedBox(width: 12),
            Expanded(child: _ConsumptionBarChart(data: data)),
          ],
        ),
      ],
    );
  }
}

class _TripsBarChart extends StatelessWidget {
  final DashboardChartData data;

  const _TripsBarChart({required this.data});

  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final spots = data.tripsPerDay
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
    final double maxY =
        (data.tripsPerDay.isEmpty
            ? 1.0
            : data.tripsPerDay.reduce((a, b) => a > b ? a : b).toDouble()) +
        2.0;
    return Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DashboardTheme.background,
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            border: Border.all(color: DashboardTheme.border),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      _days[v.toInt().clamp(0, _days.length - 1)],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: DashboardTheme.textLight,
                      ),
                    ),
                    reservedSize: 20,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: DashboardTheme.textLight,
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: DashboardTheme.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: spots.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.y,
                      color: DashboardTheme.primary,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                  showingTooltipIndicators: [],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.05, end: 0, duration: 350.ms);
  }
}

class _RevenueAreaChart extends StatelessWidget {
  final DashboardChartData data;

  const _RevenueAreaChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.revenuePerDayTnd
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxY =
        (data.revenuePerDayTnd.isEmpty
            ? 1.0
            : data.revenuePerDayTnd.reduce((a, b) => a > b ? a : b)) +
        500;
    return Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DashboardTheme.background,
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            border: Border.all(color: DashboardTheme.border),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(enabled: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, _) => Text(
                      '${(v / 1000).toStringAsFixed(0)}k',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: DashboardTheme.textLight,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: DashboardTheme.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: DashboardTheme.accent,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3,
                          color: DashboardTheme.accent,
                          strokeWidth: 0,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: DashboardTheme.accent.withOpacity(0.15),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 300),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.05, end: 0, duration: 350.ms);
  }
}

class _StatusPieChart extends StatelessWidget {
  final DashboardChartData data;

  const _StatusPieChart({required this.data});

  static const _colors = [
    DashboardTheme.accent,
    DashboardTheme.textLight,
    DashboardTheme.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.statusDistribution.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();
    final sections = entries.asMap().entries.map((e) {
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        title: '${((e.value.value / total) * 100).toStringAsFixed(0)}%',
        color: _colors[e.key % _colors.length],
        radius: 48,
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
    return Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DashboardTheme.background,
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            border: Border.all(color: DashboardTheme.border),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 24,
                  ),
                  duration: const Duration(milliseconds: 400),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _colors[e.key % _colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.value.key,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: DashboardTheme.text,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 350.ms,
        );
  }
}

class _ConsumptionBarChart extends StatelessWidget {
  final DashboardChartData data;

  const _ConsumptionBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data.topConsumption.take(5).toList();
    final maxVal = items.isEmpty
        ? 1.0
        : items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DashboardTheme.background,
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            border: Border.all(color: DashboardTheme.border),
            boxShadow: DashboardTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conso. moy. (L/100)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: DashboardTheme.textLight,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              item.$1,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: DashboardTheme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxVal > 0 ? item.$2 / maxVal : 0,
                                backgroundColor: DashboardTheme.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  DashboardTheme.alert,
                                ),
                                minHeight: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.$2.toStringAsFixed(1)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.05, end: 0, duration: 350.ms);
  }
}
