import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/dashboard_theme.dart';
import '../models/dashboard_models.dart';

class DashboardMapCard extends StatefulWidget {
  final List<DashboardTruck> trucks;
  final void Function(DashboardTruck)? onTruckTap;

  const DashboardMapCard({super.key, required this.trucks, this.onTruckTap});

  @override
  State<DashboardMapCard> createState() => _DashboardMapCardState();
}

class _DashboardMapCardState extends State<DashboardMapCard> {
  final Completer<GoogleMapController> _controller = Completer();
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(36.8, 10.18),
    zoom: 12,
  );

  Set<Marker> get _markers {
    return widget.trucks.where((t) => t.lat != null && t.lng != null).map((t) {
      return Marker(
        markerId: MarkerId(t.id),
        position: LatLng(t.lat!, t.lng!),
        icon: _markerIconForStatus(t.status),
        infoWindow: InfoWindow(
          title: t.plate,
          snippet:
              '${t.speedKmh?.toStringAsFixed(0) ?? "--"} km/h · ${t.engineTempC?.toStringAsFixed(0) ?? "--"} °C · ${t.fuelPercent?.toStringAsFixed(0) ?? "--"} %',
        ),
        onTap: () => widget.onTruckTap?.call(t),
      );
    }).toSet();
  }

  BitmapDescriptor _markerIconForStatus(TruckStatus status) {
    switch (status) {
      case TruckStatus.active:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case TruckStatus.warning:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case TruckStatus.critical:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: DashboardTheme.backgroundLight,
          borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
          boxShadow: DashboardTheme.cardShadow,
        ),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _defaultPosition,
              markers: _markers,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
              myLocationButtonEnabled: false,
              onMapCreated: (c) => _controller.complete(c),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendDot(DashboardTheme.accent, 'Actif'),
                    const SizedBox(width: 8),
                    _legendDot(DashboardTheme.alert, 'Alerte'),
                    const SizedBox(width: 8),
                    _legendDot(DashboardTheme.critical, 'Critique'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color c, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 11, color: DashboardTheme.text),
        ),
      ],
    );
  }
}
