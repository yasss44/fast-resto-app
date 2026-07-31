import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  LatLng? _lastKnownLocation;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(seconds: 30);

  /// Get current position with caching
  Future<LatLng?> getCurrentLocation({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastKnownLocation != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _lastKnownLocation;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _lastKnownLocation;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _lastKnownLocation;
      }
      if (permission == LocationPermission.deniedForever) return _lastKnownLocation;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      _lastKnownLocation = LatLng(pos.latitude, pos.longitude);
      _lastFetchTime = DateTime.now();
      return _lastKnownLocation;
    } catch (e) {
      debugPrint('LocationService.getCurrentLocation error: $e');
      return _lastKnownLocation;
    }
  }

  /// Haversine distance in km between two points
  double calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final val = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    return 2 * earthRadius * atan2(sqrt(val), sqrt(1 - val));
  }

  /// Get walking route polyline from OSRM API
  Future<List<LatLng>> getWalkingRoute(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/foot/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=false';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List<dynamic>;
          return coords.map((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('OSRM routing error: $e');
    }

    // Fallback: straight line
    return [from, to];
  }

  /// Total polyline length in km
  double routeDistanceKm(List<LatLng> route) {
    if (route.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += calculateDistance(route[i - 1], route[i]);
    }
    return total;
  }

  /// Progress 0–1 along a route based on current position
  double progressAlongRoute(LatLng current, List<LatLng> route) {
    if (route.length < 2) return 0;
    var bestProgress = 0.0;
    var walked = 0.0;
    for (var i = 1; i < route.length; i++) {
      final segStart = route[i - 1];
      final segEnd = route[i];
      final segLen = calculateDistance(segStart, segEnd);
      if (segLen <= 0) continue;
      final t = _projectOnSegment(current, segStart, segEnd);
      final projected = LatLng(
        segStart.latitude + t * (segEnd.latitude - segStart.latitude),
        segStart.longitude + t * (segEnd.longitude - segStart.longitude),
      );
      final distToSeg = calculateDistance(current, projected);
      if (distToSeg < 0.05) {
        final along = walked + segLen * t;
        final total = routeDistanceKm(route);
        return total <= 0 ? 0 : (along / total).clamp(0.0, 1.0);
      }
      walked += segLen;
      bestProgress = walked;
    }
    final total = routeDistanceKm(route);
    return total <= 0 ? 0 : (bestProgress / total).clamp(0.0, 1.0);
  }

  double _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    if (dx == 0 && dy == 0) return 0;
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) /
        (dx * dx + dy * dy);
    return t.clamp(0.0, 1.0);
  }

  static double _toRadians(double deg) => deg * pi / 180.0;
}
