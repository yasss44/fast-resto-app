import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import 'package:latlong2/latlong.dart';

/// Convert [LatLng] to [Geographic] for use with MapLibre.
Geographic toGeo(LatLng ll) => Geographic(lon: ll.longitude, lat: ll.latitude);

/// Convert coordinate doubles to [Geographic].
Geographic geo(double lat, double lon) => Geographic(lon: lon, lat: lat);

/// Register custom marker images from Flutter widgets into a MapLibre style.
/// Call this inside a `MapEventStyleLoaded` handler.
Future<void> registerMapMarkers(StyleController style) async {
  // Amber restaurant marker
  await style.addImageFromWidget(
    id: 'marker_restaurant',
    widget: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.restaurant, color: Color(0xFF09090B), size: 24),
    ),
  );

  // Blue user marker
  await style.addImageFromWidget(
    id: 'marker_user',
    widget: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 24),
    ),
  );

  // Custom driver marker (premium look)
  await style.addImageFromWidget(
    id: 'marker_driver',
    widget: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark slate
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.two_wheeler, color: Color(0xFF38BDF8), size: 32),
    ),
  );

  // Green offer/money marker
  await style.addImageFromWidget(
    id: 'marker_offer',
    widget: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
    ),
  );
}

/// OpenFreeMap Liberty style URL (vector tiles).
const openFreeMapStyle = 'https://tiles.openfreemap.org/styles/liberty';
