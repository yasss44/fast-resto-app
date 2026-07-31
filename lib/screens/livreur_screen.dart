// lib/screens/livreur_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart' as geo_loc;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../provider.dart';
import '../services/delivery_service.dart';
import '../services/map_helper.dart';
import '../api/api_exceptions.dart';

class LivreurScreen extends StatefulWidget {
  const LivreurScreen({super.key});

  @override
  State<LivreurScreen> createState() => _LivreurScreenState();
}

class _LivreurScreenState extends State<LivreurScreen> with TickerProviderStateMixin {
  final DeliveryService _deliveryService = DeliveryService();

  bool _isOnline = false;
  bool _isLoading = false;
  String? _error;
  String _driverType = 'OCCASIONAL';
  bool _isPaused = false;
  List<Map<String, dynamic>> _schedules = [];

  // Driver location tracking & MapController
  LatLng? _currentPosition;
  StreamSubscription<geo_loc.Position>? _positionSubscription;
  MapController? _mapController;
  List<dynamic> _allAvailableDeliveries = [];
  final bool _isFollowing = true;

  // Map/Heatmap animation controllers
  late AnimationController _mapPulseController;

  // Opportunity polling
  Timer? _opportunityPollTimer;
  Timer? _opportunityCountdownTimer;
  Map<String, dynamic>? _popupOpportunity;
  int _popupCountdownSeconds = 30;

  // Active delivery state
  Map<String, dynamic>? _activeDelivery;
  String _deliveryStatus = 'En attente';
  Timer? _activeDeliveryPollTimer;

  // Slogans
  final List<String> _slogans = [
    "Pas d'engagement, pas de patron",
    "Livraisons de proximité",
    "Revenus à chaque livraison",
  ];

  /// Map API status strings to French UI labels
  String _statusLabel(String apiStatus) {
    switch (apiStatus.toUpperCase()) {
      case 'AT_RESTAURANT':
        return 'Aller au restaurant';
      case 'PICKED_UP':
        return 'Livraison en cours';
      case 'DELIVERED':
        return 'Arrivé à destination';
      case 'CANCELLED':
        return 'Annulé';
      default:
        return 'En attente';
    }
  }

  @override
  void initState() {
    super.initState();
    _mapPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadDriverProfile();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _mapPulseController.dispose();
    _stopAllTimers();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    // Check permissions before fetching anything to avoid hanging
    try {
      bool serviceEnabled = await geo_loc.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      geo_loc.LocationPermission permission = await geo_loc.Geolocator.checkPermission();
      if (permission == geo_loc.LocationPermission.denied) {
        permission = await geo_loc.Geolocator.requestPermission();
        if (permission == geo_loc.LocationPermission.denied) return;
      }
      if (permission == geo_loc.LocationPermission.deniedForever) return;

      // 1. Try to get last known position first (instant, won't hang)
      final lastKnown = await geo_loc.Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
        if (_mapController != null && _isFollowing) {
          _mapController!.animateCamera(
            center: Geographic(lon: lastKnown.longitude, lat: lastKnown.latitude),
            zoom: 16.0,
          );
        }
      }

      // 2. Start stream immediately so we get updates ASAP
      const locationSettings = geo_loc.LocationSettings(
        accuracy: geo_loc.LocationAccuracy.high,
        distanceFilter: 2, // 2 meters to allow subtle emulator changes
      );

      _positionSubscription?.cancel();
      _positionSubscription = geo_loc.Geolocator.getPositionStream(locationSettings: locationSettings).listen((geo_loc.Position position) {
        if (!mounted) return;
        final latLng = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _currentPosition = latLng;
        });

        if (_isFollowing && _mapController != null) {
          _mapController!.animateCamera(
            center: Geographic(lon: position.longitude, lat: position.latitude),
            zoom: 16.0,
          );
        }
      });

      // 3. Attempt single fetch with timeout just in case stream takes too long
      geo_loc.Geolocator.getCurrentPosition(
        locationSettings: const geo_loc.LocationSettings(
          accuracy: geo_loc.LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      ).then((pos) {
        if (mounted) {
          setState(() {
            _currentPosition ??= LatLng(pos.latitude, pos.longitude);
          });
          if (_mapController != null && _isFollowing) {
            _mapController!.animateCamera(
              center: Geographic(lon: pos.longitude, lat: pos.latitude),
              zoom: 16.0,
            );
          }
        }
      }).catchError((_) {
        if (mounted && _currentPosition == null) {
          // Fallback for emulator with no location
          final fallbackPos = const LatLng(48.8566, 2.3476); // Paris fallback
          setState(() {
            _currentPosition = fallbackPos;
          });
          if (_mapController != null && _isFollowing) {
            _mapController!.animateCamera(
              center: Geographic(lon: fallbackPos.longitude, lat: fallbackPos.latitude),
              zoom: 16.0,
            );
          }
        }
      });

    } catch (_) {}
  }

  void _stopAllTimers() {
    _opportunityPollTimer?.cancel();
    _opportunityCountdownTimer?.cancel();
    _activeDeliveryPollTimer?.cancel();
  }

  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  // ── Online / Offline ──────────────────────────────────────────────

  Future<void> _loadDriverProfile() async {
    try {
      final profile = await _deliveryService.getDriverProfile();
      if (!mounted) return;
      setState(() {
        _driverType = profile['type'] as String? ?? 'OCCASIONAL';
        _isOnline = profile['isOnline'] as bool? ?? false;
        _isPaused = profile['isPaused'] as bool? ?? false;
        _schedules = (profile['schedules'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      });
      if (_isOnline && !_isPaused) {
        await _fetchActiveDelivery();
        if (_activeDelivery == null && mounted) _startOpportunityPolling();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _extractErrorMessage(e));
    }
  }

  Future<void> _toggleOnline(bool online) async {
    _clearError();
    _stopAllTimers();

    if (!online) {
      try {
        await _deliveryService.updateAvailability(isOnline: false);
      } catch (e) {
        if (mounted) setState(() => _error = _extractErrorMessage(e));
        return;
      }
      setState(() {
        _isOnline = false;
        _popupOpportunity = null;
        _activeDelivery = null;
        _deliveryStatus = 'En attente';
      });
      return;
    }

    try {
      final profile = await _deliveryService.updateAvailability(isOnline: true);
      if (!mounted) return;
      setState(() {
        _isOnline = profile['isOnline'] as bool? ?? true;
        _isPaused = profile['isPaused'] as bool? ?? false;
        _popupOpportunity = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _extractErrorMessage(e));
      return;
    }

    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        center: Geographic(lon: _currentPosition!.longitude, lat: _currentPosition!.latitude),
        zoom: 16.0,
      );
    }

    // Check if the driver already has an active delivery
    await _fetchActiveDelivery();

    // Start polling for new opportunities if no active delivery
    if (_activeDelivery == null && mounted) {
      _startOpportunityPolling();
    }
  }

  // ── Available Deliveries (Opportunities) ─────────────────────────

  void _startOpportunityPolling() {
    _opportunityPollTimer?.cancel();
    _opportunityPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_popupOpportunity != null || _activeDelivery != null) return;
      _fetchAvailableDeliveries();
    });
    // Fetch immediately on start
    _fetchAvailableDeliveries();
  }

  Future<void> _fetchAvailableDeliveries() async {
    if (!mounted) return;
    try {
      final list = await _deliveryService.getAvailableDeliveries();
      if (!mounted) return;
      setState(() {
        _allAvailableDeliveries = list;
      });
      if (list.isEmpty || _popupOpportunity != null || _activeDelivery != null) return;

      // Pick the first available opportunity
      final op = list[0] as Map<String, dynamic>;
      _showNewOpportunity(op);
    } catch (e) {
      // Silently ignore fetch errors during polling — network may be flaky
    }
  }

  void _showNewOpportunity(Map<String, dynamic> data) {
    if (!mounted) return;

    final restaurant = data['restaurant'] is Map<String, dynamic>
        ? (data['restaurant'] as Map<String, dynamic>)['name'] as String? ?? 'Restaurant'
        : data['restaurantName'] as String? ?? 'Restaurant';

    final destination = data['destination'] as String? ??
        data['dest'] as String? ??
        'Destination inconnue';

    final distance = data['distance'] as String? ??
        data['dist'] as String? ??
        '—';

    final gain = (data['gain'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      _popupCountdownSeconds = 30;
      _popupOpportunity = {
        'id': data['id'] as String,
        'restaurant': restaurant,
        'dest': destination,
        'dist': distance,
        'gain': gain,
      };
    });

    _opportunityCountdownTimer?.cancel();
    _opportunityCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_popupCountdownSeconds <= 1) {
        _declineOpportunity();
      } else {
        setState(() {
          _popupCountdownSeconds--;
        });
      }
    });
  }

  Future<void> _acceptOpportunity() async {
    if (_popupOpportunity == null) return;

    final String oppId = _popupOpportunity!['id'] as String;
    _opportunityCountdownTimer?.cancel();
    _opportunityPollTimer?.cancel();

    setState(() {
      _isLoading = true;
      _popupOpportunity = null;
    });

    try {
      await _deliveryService.acceptDelivery(oppId);
      // Fetch the now-active delivery
      await _fetchActiveDelivery();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _extractErrorMessage(e);
      });
      // Resume polling so the driver can try again
      if (_isOnline) _startOpportunityPolling();
    }
  }

  void _declineOpportunity() {
    _opportunityCountdownTimer?.cancel();
    setState(() {
      _popupOpportunity = null;
    });
  }

  // ── Active Delivery ──────────────────────────────────────────────

  Future<void> _fetchActiveDelivery() async {
    try {
      final delivery = await _deliveryService.getMyActiveDelivery();
      if (!mounted) return;

      if (delivery != null) {
        final apiStatus = delivery['status'] as String? ?? '';
        _opportunityPollTimer?.cancel();

        setState(() {
          _isLoading = false;
          _activeDelivery = _buildActiveDeliveryMap(delivery);
          _deliveryStatus = _statusLabel(apiStatus);
        });

        // If delivery is not yet complete, poll for status updates
        if (apiStatus.toUpperCase() != 'DELIVERED' && apiStatus.toUpperCase() != 'CANCELLED') {
          _startActiveDeliveryPolling();
        }
      } else {
        setState(() {
          _isLoading = false;
          _activeDelivery = null;
          _deliveryStatus = 'En attente';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _activeDelivery = null;
      });
    }
  }

  Map<String, dynamic> _buildActiveDeliveryMap(Map<String, dynamic> data) {
    final restaurant = data['restaurant'] is Map<String, dynamic>
        ? (data['restaurant'] as Map<String, dynamic>)['name'] as String? ?? 'Restaurant'
        : data['restaurantName'] as String? ?? 'Restaurant';

    final destination = data['destination'] as String? ??
        data['dest'] as String? ??
        'Destination inconnue';

    final distance = data['distance'] as String? ??
        data['dist'] as String? ??
        '—';

    final gain = (data['gain'] as num?)?.toDouble() ?? 0.0;

    return {
      'id': data['id'] as String,
      'restaurant': restaurant,
      'dest': destination,
      'dist': distance,
      'gain': gain,
    };
  }

  void _startActiveDeliveryPolling() {
    _activeDeliveryPollTimer?.cancel();
    _activeDeliveryPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshActiveDelivery();
    });
  }

  Future<void> _refreshActiveDelivery() async {
    try {
      final delivery = await _deliveryService.getMyActiveDelivery();
      if (!mounted) return;

      if (delivery == null) {
        // Delivery completed or cancelled on the backend side
        setState(() {
          _activeDelivery = null;
          _deliveryStatus = 'En attente';
        });
        _activeDeliveryPollTimer?.cancel();
        if (_isOnline) _startOpportunityPolling();
        return;
      }

      final apiStatus = delivery['status'] as String? ?? '';
      setState(() {
        _activeDelivery = _buildActiveDeliveryMap(delivery);
        _deliveryStatus = _statusLabel(apiStatus);
      });

      // Stop polling if delivery reached a terminal state
      if (apiStatus.toUpperCase() == 'DELIVERED' || apiStatus.toUpperCase() == 'CANCELLED') {
        _activeDeliveryPollTimer?.cancel();
      }
    } catch (_) {}
  }

  // ── Status Progression (Driver Actions) ──────────────────────────

  Future<void> _confirmPickup() async {
    if (_activeDelivery == null) return;
    final String deliveryId = _activeDelivery!['id'] as String;

    setState(() => _isLoading = true);

    try {
      await _deliveryService.updateDeliveryStatus(deliveryId, 'PICKED_UP');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _deliveryStatus = 'Livraison en cours';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _extractErrorMessage(e);
      });
    }
  }

  Future<void> _confirmDelivery() async {
    if (_activeDelivery == null) return;
    final String deliveryId = _activeDelivery!['id'] as String;
    final gain = _activeDelivery!['gain'] ?? 0.0;

    setState(() => _isLoading = true);

    try {
      await _deliveryService.updateDeliveryStatus(deliveryId, 'DELIVERED');
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show success dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF10B981)),
          ),
          title: const Text('🎉 Livré !',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
            'Revenus crédités : +${gain.toStringAsFixed(2)} €.\nMerci pour cette livraison de proximité !',
            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _activeDeliveryPollTimer?.cancel();
                setState(() {
                  _activeDelivery = null;
                  _deliveryStatus = 'En attente';
                });
                if (_isOnline) {
                  _startOpportunityPolling();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF09090B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _extractErrorMessage(e);
      });
    }
  }

  String _extractErrorMessage(dynamic e) {
    if (e is ApiException) return e.message;
    if (e is String) return e;
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  Future<void> _togglePause() async {
    try {
      final profile = await _deliveryService.updateAvailability(isPaused: !_isPaused);
      if (!mounted) return;
      setState(() => _isPaused = profile['isPaused'] as bool? ?? !_isPaused);
      if (_isPaused) {
        _stopAllTimers();
      } else if (_isOnline) {
        _startOpportunityPolling();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _extractErrorMessage(e));
    }
  }

  Future<void> _editPermanentSchedule() async {
    final selectedDays = _schedules
        .map((slot) => (slot['dayOfWeek'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    if (selectedDays.isEmpty) selectedDays.addAll({1, 2, 3, 4, 5});
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay finish = const TimeOfDay(hour: 17, minute: 0);
    if (_schedules.isNotEmpty) {
      final startMinute = (_schedules.first['startMinute'] as num?)?.toInt() ?? 540;
      final endMinute = (_schedules.first['endMinute'] as num?)?.toInt() ?? 1020;
      start = TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60);
      finish = TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60);
    }

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Créneaux permanents', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Sélectionnez vos jours habituels. Vous pourrez mettre le service en pause à tout moment.', style: TextStyle(color: Color(0xFFA1A1AA), height: 1.4)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      return FilterChip(
                        label: Text(labels[index]),
                        selected: selectedDays.contains(day),
                        onSelected: (selected) => setSheetState(() {
                          selected ? selectedDays.add(day) : selectedDays.remove(day);
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text('Début ${start.format(context)}'),
                          onPressed: () async {
                            final value = await showTimePicker(context: context, initialTime: start);
                            if (value != null) setSheetState(() => start = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text('Fin ${finish.format(context)}'),
                          onPressed: () async {
                            final value = await showTimePicker(context: context, initialTime: finish);
                            if (value != null) setSheetState(() => finish = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selectedDays.isEmpty ? null : () => Navigator.pop(sheetContext, true),
                      child: const Text('Enregistrer les créneaux'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (shouldSave != true) return;
    final startMinute = start.hour * 60 + start.minute;
    final endMinute = finish.hour * 60 + finish.minute;
    if (endMinute <= startMinute) {
      if (mounted) setState(() => _error = 'L’heure de fin doit être après l’heure de début.');
      return;
    }
    try {
      final profile = await _deliveryService.replaceSchedules(
        timezone: 'Europe/Paris',
        schedules: selectedDays.map((day) => {
          'dayOfWeek': day,
          'startMinute': startMinute,
          'endMinute': endMinute,
          'isEnabled': true,
        }).toList(),
      );
      if (!mounted) return;
      setState(() {
        _schedules = (profile['schedules'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _isOnline = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _extractErrorMessage(e));
    }
  }

  // ── UI Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Espace Livreur',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 16),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'EN LIGNE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Map (MapLibre GL + OpenFreeMap)
          Positioned.fill(
            child: Consumer<FASTProvider>(
              builder: (context, provider, _) {
                final restPoints = provider.restaurants.map((r) =>
                  Feature<Point>(geometry: Point(geo(r.latitude, r.longitude))),
                ).toList();

                final offerPoints = <Feature<Point>>[];
                if (_isOnline) {
                  for (final d in _allAvailableDeliveries) {
                    final restId = d['restaurantId'] as String?;
                    if (restId != null) {
                      final matching = provider.restaurants.where((r) => r.id == restId);
                      if (matching.isNotEmpty) {
                        final rest = matching.first;
                        offerPoints.add(Feature<Point>(
                          geometry: Point(geo(rest.latitude, rest.longitude)),
                        ));
                      }
                    }
                  }
                }

                return MapLibreMap(
                  options: MapOptions(
                    initStyle: openFreeMapStyle,
                    initCenter: _currentPosition != null
                        ? Geographic(lon: _currentPosition!.longitude, lat: _currentPosition!.latitude)
                        : const Geographic(lon: 2.3522, lat: 48.8566),
                    initZoom: _currentPosition != null ? 16.0 : 12.0,
                    gestures: const MapGestures.all(),
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_currentPosition != null && _isFollowing) {
                      controller.animateCamera(
                        center: Geographic(lon: _currentPosition!.longitude, lat: _currentPosition!.latitude),
                        zoom: 16.0,
                      );
                    }
                  },
                  onEvent: (event) async {
                    if (event case MapEventStyleLoaded()) {
                      await registerMapMarkers(event.style);
                    }
                  },
                  layers: [
                    if (restPoints.isNotEmpty)
                      MarkerLayer(
                        points: restPoints,
                        iconImage: 'marker_restaurant',
                        iconSize: 1.0,
                        iconAnchor: IconAnchor.center,
                        iconAllowOverlap: true,
                        iconIgnorePlacement: true,
                      ),
                    if (_isOnline && offerPoints.isNotEmpty)
                      MarkerLayer(
                        points: offerPoints,
                        iconImage: 'marker_offer',
                        iconSize: 1.0,
                        iconAnchor: IconAnchor.center,
                        iconAllowOverlap: true,
                        iconIgnorePlacement: true,
                      ),
                    if (_currentPosition != null)
                      MarkerLayer(
                        points: [
                          Feature<Point>(geometry: Point(Geographic(lon: _currentPosition!.longitude, lat: _currentPosition!.latitude))),
                        ],
                        iconImage: 'marker_driver',
                        iconSize: 1.0,
                        iconAnchor: IconAnchor.center,
                        iconAllowOverlap: true,
                        iconIgnorePlacement: true,
                      ),
                  ],
                );
              },
            ),
          ),

          // Top overlay controls
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSlogansHeader(),
                const SizedBox(height: 12),
                _buildOnlineControlPanel(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildErrorBanner(),
                  ),
              ],
            ),
          ),

          // Active delivery panel (bottom)
          if (_isOnline && _activeDelivery != null && !_isLoading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildActiveDeliveryPanel(),
            ),

          // Loading overlay for API operations
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  ),
                ),
              ),
            ),

          // DoorDash-style Opportunity Alert Pop-up
          if (_isOnline && _popupOpportunity != null && !_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: _buildOpportunityPopup(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: _clearError,
            child: const Icon(Icons.close, color: Color(0xFFFCA5A5), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSlogansHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _driverType == 'PERMANENT' ? Icons.calendar_month_outlined : Icons.flash_on_outlined,
                color: const Color(0xFFF59E0B),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _driverType == 'PERMANENT' ? 'Livreur permanent FAST' : 'Livreur occasionnel FAST',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              if (_driverType == 'PERMANENT')
                TextButton.icon(
                  onPressed: _editPermanentSchedule,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: Text('${_schedules.length} créneau${_schedules.length > 1 ? 'x' : ''}'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _slogans.map((slogan) {
              return Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 10),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        slogan,
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 9, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isOnline ? const Color(0xFF0C1D1A).withValues(alpha: 0.95) : const Color(0xFF18181B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF27272A),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPaused
                    ? 'SERVICE EN PAUSE'
                    : _isOnline
                        ? 'MODE LIVRAISON EN LIGNE'
                        : 'MODE LIVRAISON HORS LIGNE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF71717A),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isPaused
                    ? 'Reprenez lorsque vous êtes disponible'
                    : _isOnline
                        ? 'En attente d\'opportunités...'
                        : _driverType == 'PERMANENT' && _schedules.isEmpty
                            ? 'Ajoutez vos créneaux réguliers'
                            : 'Passez en ligne pour recevoir des courses',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_driverType == 'PERMANENT' && _isOnline)
                IconButton(
                  tooltip: _isPaused ? 'Reprendre' : 'Mettre en pause',
                  onPressed: _togglePause,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                ),
              Switch(
                value: _isOnline,
                onChanged: (v) => _toggleOnline(v),
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                inactiveThumbColor: const Color(0xFF71717A),
                inactiveTrackColor: const Color(0xFF27272A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityPopup() {
    final op = _popupOpportunity!;
    final progress = _popupCountdownSeconds / 30.0;

    return Container(
      width: 310,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with money gain
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'COURSE PROCHE',
                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 9),
                ),
              ),
              Text(
                '+${(op['gain'] as num).toStringAsFixed(2)} €',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Restaurant info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, color: Color(0xFFF59E0B), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RETRAIT', style: TextStyle(fontSize: 8, color: Color(0xFF71717A), fontWeight: FontWeight.bold)),
                    Text(op['restaurant'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LIVRAISON', style: TextStyle(fontSize: 8, color: Color(0xFF71717A), fontWeight: FontWeight.bold)),
                    Text(op['dest'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF27272A)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Distance : ${op['dist'] as String}',
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold)),
              // Countdown Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF27272A),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                      strokeWidth: 3,
                    ),
                  ),
                  Text(
                    '$_popupCountdownSeconds',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Accept / Decline Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _declineOpportunity,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Décliner', style: TextStyle(color: Color(0xFFA1A1AA), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _acceptOpportunity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF09090B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Accepter la course', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryPanel() {
    final d = _activeDelivery!;

    // Determine which action button to show based on delivery status
    final bool showPickupButton = _deliveryStatus == 'Aller au restaurant' || _deliveryStatus == 'En attente';
    final bool showDeliverButton = _deliveryStatus == 'Livraison en cours';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVRAISON EN COURS',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent.shade200,
                    letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _deliveryStatus.toUpperCase(),
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            d['restaurant'] as String,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            'Dest : ${d['dest'] as String} (${d['dist'] as String})',
            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGoogleMaps(d['restaurant'] as String),
                  icon: const Icon(Icons.storefront, size: 16),
                  label: const Text('Nav. restaurant', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGoogleMaps(d['dest'] as String),
                  icon: const Icon(Icons.place_outlined, size: 16),
                  label: const Text('Nav. destination', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (showPickupButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmPickup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF09090B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Confirmer la récupération du colis',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
          else if (showDeliverButton || _deliveryStatus == 'Arrivé à destination')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF09090B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Confirmer la remise au client',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B))),
                ),
                SizedBox(width: 8),
                Text(
                  'Mise à jour du trajet en cours...',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
