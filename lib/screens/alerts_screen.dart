import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alerts_provider.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF00E5FF), size: 24),
            const SizedBox(width: 10),
            const Text('Alertes IA',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20)),
            const SizedBox(width: 8),
            if (state.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${state.unreadCount}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(alertsProvider.notifier).markAllAsRead(),
              icon:
                  const Icon(Icons.done_all, color: Color(0xFF00E5FF), size: 18),
              label: const Text('Tout lire',
                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13)),
            ),
          IconButton(
            onPressed: () => ref.read(alertsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : state.alerts.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(alertsProvider.notifier).refresh(),
                  color: const Color(0xFF00E5FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.alerts.length,
                    itemBuilder: (ctx, i) =>
                        _AlertCard(alert: state.alerts[i], ref: ref),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined,
              size: 80, color: Colors.greenAccent.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Aucune alerte',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tout fonctionne normalement',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final FleetAlert alert;
  final WidgetRef ref;
  const _AlertCard({required this.alert, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.severity == 'critical';
    final color = _alertColor(alert.alertType, alert.severity);
    final icon = _alertIcon(alert.alertType);
    final timeAgo = _formatTimeAgo(alert.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!alert.isRead) {
              ref.read(alertsProvider.notifier).markAsRead(alert.id);
            }
            _showAlertDetail(context);
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(alert.isRead ? 0.04 : 0.1),
                  const Color(0xFF1A2636),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(alert.isRead ? 0.1 : 0.3),
                width: alert.isRead ? 1 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!alert.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    alert.isRead ? FontWeight.w500 : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Severity badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCritical ? 'CRITIQUE' : 'ALERTE',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              color: Colors.white.withOpacity(0.3), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            alert.camion,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.access_time,
                              color: Colors.white.withOpacity(0.3), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetail(BuildContext context) {
    final color = _alertColor(alert.alertType, alert.severity);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2636),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(_alertIcon(alert.alertType), color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(alert.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Type', alert.alertType.replaceAll('_', ' '), color),
            _detailRow('Camion', alert.camion, color),
            _detailRow('Sévérité',
                alert.severity == 'critical' ? 'CRITIQUE' : 'AVERTISSEMENT', color),
            _detailRow(
                'Date', DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt), color),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Text(alert.message,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Color _alertColor(String type, String severity) {
    if (severity == 'critical') return const Color(0xFFFF5252);
    switch (type) {
      case 'CONDUITE_DANGEREUSE':
        return const Color(0xFFFF9800);
      case 'MAINTENANCE':
        return const Color(0xFF2196F3);
      case 'VOL_CARBURANT':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFF00BCD4);
    }
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'CONDUITE_DANGEREUSE':
        return Icons.warning_amber_rounded;
      case 'MAINTENANCE':
        return Icons.build_circle_outlined;
      case 'VOL_CARBURANT':
        return Icons.local_gas_station;
      default:
        return Icons.notifications_active;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return DateFormat('dd/MM').format(dt);
  }
}
