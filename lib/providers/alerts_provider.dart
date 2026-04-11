import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Data Model ───

class FleetAlert {
  final int id;
  final DateTime createdAt;
  final String camion;
  final String alertType;
  final String title;
  final String message;
  final String severity;
  final bool isRead;

  const FleetAlert({
    required this.id,
    required this.createdAt,
    required this.camion,
    required this.alertType,
    required this.title,
    required this.message,
    required this.severity,
    required this.isRead,
  });

  factory FleetAlert.fromJson(Map<String, dynamic> json) {
    return FleetAlert(
      id: json['id'] as int,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      camion: json['camion'] as String? ?? '',
      alertType: json['alert_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

// ─── State ───

class AlertsState {
  final List<FleetAlert> alerts;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const AlertsState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  AlertsState copyWith({
    List<FleetAlert>? alerts,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// ─── Provider ───

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  return AlertsNotifier();
});

class AlertsNotifier extends StateNotifier<AlertsState> {
  AlertsNotifier() : super(const AlertsState()) {
    _init();
  }

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  void _init() {
    _fetchAlerts();
    _listenRealtime();
    // Fallback polling every 15s
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchAlerts();
    });
  }

  Future<void> _fetchAlerts() async {
    try {
      final response = await _supabase
          .from('alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      final alerts =
          (response as List).map((e) => FleetAlert.fromJson(e)).toList();
      final unread = alerts.where((a) => !a.isRead).length;

      state = state.copyWith(
        alerts: alerts,
        isLoading: false,
        unreadCount: unread,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void _listenRealtime() {
    _channel = _supabase.channel('alerts_realtime');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            final newAlert = FleetAlert.fromJson(payload.newRecord);
            state = state.copyWith(
              alerts: [newAlert, ...state.alerts],
              unreadCount: state.unreadCount + 1,
            );
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(int alertId) async {
    try {
      await _supabase
          .from('alerts')
          .update({'is_read': true}).eq('id', alertId);
      state = state.copyWith(
        alerts: state.alerts.map((a) {
          if (a.id == alertId) {
            return FleetAlert(
              id: a.id,
              createdAt: a.createdAt,
              camion: a.camion,
              alertType: a.alertType,
              title: a.title,
              message: a.message,
              severity: a.severity,
              isRead: true,
            );
          }
          return a;
        }).toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('alerts')
          .update({'is_read': true}).eq('is_read', false);
      state = state.copyWith(
        alerts: state.alerts.map((a) {
          return FleetAlert(
            id: a.id,
            createdAt: a.createdAt,
            camion: a.camion,
            alertType: a.alertType,
            title: a.title,
            message: a.message,
            severity: a.severity,
            isRead: true,
          );
        }).toList(),
        unreadCount: 0,
      );
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _fetchAlerts();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _pollTimer?.cancel();
    super.dispose();
  }
}
