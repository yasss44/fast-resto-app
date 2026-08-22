// lib/screens/commandes_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart' as geo_loc;
import '../provider.dart';
import '../models.dart';
import '../services/map_helper.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../services/delivery_service.dart';
import 'qr_screen.dart';

class CommandesScreen extends StatefulWidget {
  const CommandesScreen({super.key});

  @override
  State<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends State<CommandesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _orderService = OrderService();
  final _deliveryService = DeliveryService();

  // Delivery tracking
  Timer? _deliveryPollTimer;
  String? _deliveryStatusLabel;
  String? _deliveryDriverName;
  String? _deliveryPollingOrderId;

  // Active order tracking
  int _selectedActiveIndex = 0;
  List<LatLng> _routePolyline = [];
  double _walkProgress = 0;
  StreamSubscription<geo_loc.Position>? _locationSub;
  String? _trackingOrderId;
  DateTime? _lastTrackingPatch;

  // Active Order (Suivi) Animations
  late AnimationController _pulseController;
  late AnimationController _confettiController;
  bool _ratingSubmitted = false;
  double _pendingRating = 0;
  final TextEditingController _commentController = TextEditingController();
  String? _lastCompletedId;

  // Order History States
  final Map<String, double> _orderRatings = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Default to History if no active orders exist, otherwise default to Tracking
    final provider = Provider.of<FASTProvider>(context, listen: false);
    final hasActiveOrder = provider.orders.any(
      (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
    );
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: hasActiveOrder ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _deliveryPollTimer?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    _commentController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getHistoryController(String orderId) {
    if (!_controllers.containsKey(orderId)) {
      _controllers[orderId] = TextEditingController();
    }
    return _controllers[orderId]!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final surface = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Commandes',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFF59E0B),
              indicatorWeight: 2,
              labelColor: const Color(0xFFF59E0B),
              unselectedLabelColor: const Color(0xFF71717A),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Suivi en cours'),
                Tab(text: 'Historique'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuiviTab(provider),
          _buildHistoriqueTab(provider),
        ],
      ),
    );
  }

  // ─── SUIVI TAB ─────────────────────────────────────────────────────────────
  Widget _buildSuiviTab(FASTProvider provider) {
    final activeOrders = provider.orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
        .toList();

    if (activeOrders.isEmpty) {
      _stopLocationTracking();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚶', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Aucun suivi actif',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Passez une commande depuis le panier pour activer le suivi de marche !',
                style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.navigateToScreen('home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF09090B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Découvrir les restaurants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedActiveIndex >= activeOrders.length) {
      _selectedActiveIndex = 0;
    }
    final activeOrder = activeOrders[_selectedActiveIndex];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTrackingForOrder(provider, activeOrder);
    });

    final isCompleted = activeOrder.status == OrderStatus.completed;
    final isCancelled = activeOrder.status == OrderStatus.cancelled;
    final walkProgress = isCompleted
        ? 1.0
        : isCancelled
            ? 0.0
            : _walkProgress.clamp(0.0, 1.0);

    // Trigger confetti when a new completion is detected
    if (isCompleted && _lastCompletedId != activeOrder.id) {
      _lastCompletedId = activeOrder.id;
      _ratingSubmitted = activeOrder.userRatingSubmitted;
      _pendingRating = 0;
      _confettiController.forward(from: 0);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeOrders.length > 1) ...[
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final o = activeOrders[index];
                      final selected = index == _selectedActiveIndex;
                      return ChoiceChip(
                        label: Text(
                          o.restaurantName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected ? const Color(0xFF09090B) : Colors.white,
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFFF59E0B),
                        backgroundColor: const Color(0xFF18181B),
                        onSelected: (_) => setState(() => _selectedActiveIndex = index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildTrackerHeader(context, activeOrder, isCompleted, isCancelled),
              const SizedBox(height: 16),
              if (!isCancelled) ...[
                if (activeOrder.isDelivery) ...[
                  const Text(
                    'SUIVI LIVRAISON',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDeliveryTrackingCard(activeOrder),
                ] else ...[
                  const Text(
                    'SUIVI GPS — TRAJET VERS LE RESTAURANT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildVectorMapCard(context, walkProgress, activeOrder),
                ],
                const SizedBox(height: 16),
              ],

              // Contextual status text card
              _buildStatusDescriptionCard(context, activeOrder, isCompleted, isCancelled),
              const SizedBox(height: 20),

              // QR Verification button — pickup only
              if (!activeOrder.isDelivery &&
                  (activeOrder.status == OrderStatus.readyForPickup || isCompleted))
                _buildQRButton(context, activeOrder),

              // Cancellation trigger
              if (!isCompleted && !isCancelled)
                _buildCancelAction(context, provider, activeOrder),

              const SizedBox(height: 80),
            ],
          ),
        ),

        // Confetti + Rating overlay when completed
        if (isCompleted)
          _buildCompletionOverlay(context, provider, activeOrder),
      ],
    );
  }

  Widget _buildTrackerHeader(BuildContext context, Order order, bool isCompleted, bool isCancelled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              order.restaurantImage,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey, width: 56, height: 56),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SUIVI ACTIF • ${order.id}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  order.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.directions_walk, size: 12, color: Color(0xFFA1A1AA)),
                    const SizedBox(width: 4),
                    Text(
                      isCompleted
                          ? 'Récupéré'
                          : isCancelled
                              ? 'Annulé'
                              : 'Arrivée estimée dans : ${order.userWalkTimeMinutes} min',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case OrderStatus.placed:
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue;
        label = 'COMMANDÉ';
        break;
      case OrderStatus.preparing:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        label = 'EN COURS';
        break;
      case OrderStatus.readyForPickup:
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        label = 'PRÊT';
        break;
      case OrderStatus.completed:
        bg = const Color(0xFF71717A).withValues(alpha: 0.15);
        fg = const Color(0xFFA1A1AA);
        label = 'RÉCUPÉRÉ';
        break;
      case OrderStatus.cancelled:
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red;
        label = 'ANNULÉ';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildVectorMapCard(BuildContext context, double progress, Order order) {
    final provider = Provider.of<FASTProvider>(context, listen: false);
    final rest = provider.restaurants.where((r) => r.id == order.restaurantId).firstOrNull;
    final restLat = rest?.latitude ?? 48.8566;
    final restLon = rest?.longitude ?? 2.3522;

    final userLoc = provider.userLocation;
    final userLat = userLoc?.latitude ?? 48.8566;
    final userLon = userLoc?.longitude ?? 2.3476;

    final midLat = (userLat + restLat) / 2;
    final midLon = (userLon + restLon) / 2;

    final routePoints = _routePolyline.isNotEmpty
        ? _routePolyline
        : [LatLng(userLat, userLon), LatLng(restLat, restLon)];

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MapLibreMap(
            options: MapOptions(
              initStyle: openFreeMapStyle,
              initCenter: geo(midLat, midLon),
              initZoom: 14.0,
              gestures: const MapGestures.all(),
            ),
            onEvent: (event) async {
              if (event case MapEventStyleLoaded()) {
                await registerMapMarkers(event.style);
              }
            },
            layers: [
              PolylineLayer(
                polylines: [
                  Feature(
                    geometry: LineString.from(
                      routePoints.map((p) => geo(p.latitude, p.longitude)).toList(),
                    ),
                  ),
                ],
                color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                width: 3,
              ),
              MarkerLayer(
                points: [Feature(geometry: Point(geo(userLat, userLon)))],
                iconImage: 'marker_user',
                iconSize: 0.2,
                iconAnchor: IconAnchor.center,
              ),
              MarkerLayer(
                points: [Feature(geometry: Point(geo(restLat, restLon)))],
                iconImage: 'marker_restaurant',
                iconSize: 0.2,
                iconAnchor: IconAnchor.center,
              ),
            ],
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(progress * 100).round()} % du trajet',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ensureTrackingForOrder(FASTProvider provider, Order order) {
    if (order.isDelivery) {
      if (_deliveryPollingOrderId == order.id) return;
      _stopLocationTracking();
      _stopDeliveryPolling();
      _deliveryPollingOrderId = order.id;
      _fetchDeliveryStatus(order.id);
      _deliveryPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchDeliveryStatus(order.id);
      });
      return;
    }
    if (_trackingOrderId == order.id) return;
    _stopDeliveryPolling();
    _stopLocationTracking();
    _trackingOrderId = order.id;
    _routePolyline = [];
    _walkProgress = (order.gpsProgress / 100).clamp(0.0, 1.0);
    _startLocationTracking(provider, order);
  }

  void _stopDeliveryPolling() {
    _deliveryPollTimer?.cancel();
    _deliveryPollTimer = null;
    _deliveryPollingOrderId = null;
    _deliveryStatusLabel = null;
    _deliveryDriverName = null;
  }

  Future<void> _fetchDeliveryStatus(String orderId) async {
    try {
      final data = await _deliveryService.getOrderDelivery(orderId);
      final delivery = data['delivery'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _deliveryStatusLabel = _deliveryStatusToLabel(delivery?['status'] as String?);
        final driver = delivery?['driver'] as Map<String, dynamic>?;
        _deliveryDriverName = driver?['name'] as String?;
      });
    } catch (_) {}
  }

  String _deliveryStatusToLabel(String? status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Recherche d\'un livreur…';
      case 'ACCEPTED':
        return 'Livreur assigné — en route vers le restaurant';
      case 'AT_RESTAURANT':
        return 'Livreur au restaurant';
      case 'PICKED_UP':
        return 'En route vers vous !';
      case 'DELIVERED':
        return 'Livré';
      default:
        return 'Commande en cours de préparation';
    }
  }

  Widget _buildDeliveryTrackingCard(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _deliveryStatusLabel ?? _deliveryStatusToLabel(order.deliveryStatus),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (_deliveryDriverName != null) ...[
            const SizedBox(height: 10),
            Text('Livreur : $_deliveryDriverName', style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1AA))),
          ],
          if (order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('📍 ${order.deliveryAddress}', style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
          ],
        ],
      ),
    );
  }

  void _stopLocationTracking() {
    _locationSub?.cancel();
    _locationSub = null;
    _trackingOrderId = null;
  }

  Future<void> _startLocationTracking(FASTProvider provider, Order order) async {
    final rest = provider.restaurants.where((r) => r.id == order.restaurantId).firstOrNull;
    if (rest == null) return;

    final restPoint = LatLng(rest.latitude, rest.longitude);
    final start = await LocationService.instance.getCurrentLocation(forceRefresh: true);
    if (start != null) {
      _routePolyline = await LocationService.instance.getWalkingRoute(start, restPoint);
      if (mounted) setState(() {});
    }

    const settings = geo_loc.LocationSettings(
      accuracy: geo_loc.LocationAccuracy.high,
      distanceFilter: 15,
    );

    _locationSub = geo_loc.Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      if (!mounted || _trackingOrderId != order.id) return;
      final current = LatLng(pos.latitude, pos.longitude);
      provider.fetchUserLocation();

      if (_routePolyline.isEmpty) {
        _routePolyline = await LocationService.instance.getWalkingRoute(current, restPoint);
      }

      final progress = LocationService.instance.progressAlongRoute(current, _routePolyline);
      _walkProgress = progress;

      final now = DateTime.now();
      if (_lastTrackingPatch == null || now.difference(_lastTrackingPatch!) > const Duration(seconds: 20)) {
        _lastTrackingPatch = now;
        try {
          await _orderService.updateTracking(
            orderId: order.id,
            gpsProgress: progress * 100,
            latitude: pos.latitude,
            longitude: pos.longitude,
            isReadyAtEntrance: progress >= 0.92,
          );
          provider.updateOrderTrackingLocally(
            order.id,
            gpsProgress: progress * 100,
            isReadyAtEntrance: progress >= 0.92,
          );
        } catch (_) {}
      }

      if (mounted) setState(() {});
    });
  }

  Widget _buildStatusDescriptionCard(BuildContext context, Order order, bool isCompleted, bool isCancelled) {
    String title = '';
    String desc = '';
    IconData icon = Icons.info;
    Color iconColor = const Color(0xFFF59E0B);

    if (isCancelled) {
      title = 'Commande annulée';
      desc = 'Cette commande a été annulée conformément à notre politique d\'annulation transparente. Consultez l\'historique pour les détails de transaction.';
      icon = Icons.cancel;
      iconColor = Colors.red;
    } else if (isCompleted) {
      title = 'Remise effectuée !';
      desc = 'Vous avez récupéré votre commande via FAST Click & Collect. Repas frais et chaud entre vos mains. Bon appétit !';
      icon = Icons.handshake;
      iconColor = const Color(0xFF10B981);
    } else {
      switch (order.status) {
        case OrderStatus.placed:
          title = 'Commande enregistrée !';
          desc = 'La cuisine synchronise les terminaux. Mettez-vous en route maintenant !';
          icon = Icons.receipt_long;
          iconColor = Colors.blue;
          break;
        case OrderStatus.preparing:
          title = 'Vos artisans cuisinent 🍳';
          desc = 'La cuisine a démarré la préparation. Ils ajustent la cuisson dynamiquement selon votre temps de marche.';
          icon = Icons.restaurant_menu;
          iconColor = const Color(0xFFF59E0B);
          break;
        case OrderStatus.readyForPickup:
          title = 'Repas chaud et prêt ! 🔥';
          desc = 'La cuisine a posé votre repas sur le comptoir Click & Collect. Montrez le QR au staff pour confirmer la remise.';
          icon = Icons.backpack;
          iconColor = const Color(0xFF10B981);
          break;
        default:
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRButton(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => QRVerificationScreen(order: order),
              fullscreenDialog: true,
            ));
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.qr_code, color: Color(0xFFF59E0B), size: 18),
          label: const Text(
            'Montrer le QR au staff',
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelAction(BuildContext context, FASTProvider provider, Order order) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: TextButton(
          onPressed: () => _showHonestCancellationSheet(context, provider, order),
          child: const Text(
            'Annuler la commande',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _showHonestCancellationSheet(BuildContext context, FASTProvider provider, Order order) {
    final bool prepStarted = order.status != OrderStatus.placed;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text(
                    'Politique d\'annulation',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Chez FAST, notre politique d\'annulation est transparente et simple. Pas de petits caractères :',
                style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA), height: 1.4),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: !prepStarted ? const Color(0xFF0C1D1A) : const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !prepStarted ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      !prepStarted ? Icons.check_circle : Icons.radio_button_off,
                      color: !prepStarted ? const Color(0xFF10B981) : const Color(0xFF71717A),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cas 1 : Annulation avant préparation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Remboursement intégral (hors frais de service 1,50 € utilisés pour le traitement).',
                            style: TextStyle(fontSize: 10, color: Color(0xFFA1A1AA), height: 1.3),
                          ),
                          if (!prepStarted) ...[
                            const SizedBox(height: 6),
                            Text(
                              '👉 ACTIF. Remboursement : ${order.subtotal.toStringAsFixed(2)} €',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF10B981)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: prepStarted ? const Color(0xFF2D1616) : const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: prepStarted ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      prepStarted ? Icons.error : Icons.radio_button_off,
                      color: prepStarted ? const Color(0xFFEF4444) : const Color(0xFF71717A),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cas 2 : Annulation après préparation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Débit total appliqué. La cuisine a déjà utilisé les ingrédients frais pour votre repas.',
                            style: TextStyle(fontSize: 10, color: Color(0xFFA1A1AA), height: 1.3),
                          ),
                          if (prepStarted) ...[
                            const SizedBox(height: 6),
                            Text(
                              '👉 ACTIF. Débit : ${order.total.toStringAsFixed(2)} €',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF27272A)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Garder la commande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.cancelOrder(order.id);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Confirmer l\'annulation', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionOverlay(BuildContext context, FASTProvider provider, Order order) {
    if (_ratingSubmitted && _confettiController.isCompleted) return const SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          final confettiFade = _confettiController.value < 0.7 ? 1.0 : (1.0 - (_confettiController.value - 0.7) / 0.3);
          return Stack(
            children: [
              if (_confettiController.value < 0.9)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: confettiFade.clamp(0.0, 1.0),
                      child: CustomPaint(
                        painter: _ConfettiPainter(
                          progress: _confettiController.value,
                          seed: order.id.hashCode,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_ratingSubmitted)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildRatingCard(context, provider, order),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingCard(BuildContext context, FASTProvider provider, Order order) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF27272A)),
          left: BorderSide(color: Color(0xFF27272A)),
          right: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3F3F46),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Récupéré !',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      order.restaurantName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Comment s\'est passée votre expérience ?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (context, setInnerState) {
              return Row(
                children: List.generate(5, (i) {
                  final filled = i < _pendingRating;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _pendingRating = (i + 1).toDouble());
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: filled ? const Color(0xFFF59E0B) : const Color(0xFF3F3F46),
                        size: 32,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _commentController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Laissez un commentaire (optionnel)...',
              hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF09090B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF59E0B)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _ratingSubmitted = true),
                  child: const Text(
                    'Passer',
                    style: TextStyle(color: Color(0xFF71717A), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _pendingRating == 0
                      ? null
                      : () {
                          provider.submitRestaurantRating(
                            order.id,
                            order.restaurantId,
                            _pendingRating,
                            _commentController.text.trim(),
                          );
                          setState(() => _ratingSubmitted = true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF09090B),
                    disabledBackgroundColor: const Color(0xFF27272A),
                    disabledForegroundColor: const Color(0xFF52525B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Envoyer l\'avis',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── HISTORIQUE TAB ────────────────────────────────────────────────────────
  Widget _buildHistoriqueTab(FASTProvider provider) {
    final orders = provider.orders;

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📜', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Aucun historique de commande',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Une fois que vous aurez récupéré des commandes Click & Collect, l\'historique apparaîtra ici.',
                style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderHistoryCard(context, provider, order);
      },
    );
  }

  Widget _buildOrderHistoryCard(BuildContext context, FASTProvider provider, Order order) {
    final formattedDate = _parseIsoDate(order.createdAt);
    final isCompleted = order.status == OrderStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF09090B),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    order.restaurantImage,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey, width: 44, height: 44),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.id,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                          _buildStatusLabel(order.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.restaurantName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Commandé le : $formattedDate',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Items list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((cartItem) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${cartItem.quantity}x  ${cartItem.menuItem.name}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFE4E4E7)),
                        ),
                        Text(
                          '€${(cartItem.menuItem.price * cartItem.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA), fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                }),
                
                const Divider(color: Color(0xFF27272A), height: 20),
                
                // commission flat fee
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Frais de service FAST', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                    Text('€${order.serviceFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Color(0xFF71717A), fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 6),
                // total paid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total payé',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '€${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF59E0B),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rating Feedback panel (only for completed orders)
          if (isCompleted) ...[
            const Divider(color: Color(0xFF27272A), height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF09090B).withValues(alpha: 0.3),
              child: order.userRatingSubmitted
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Avis envoyé avec succès !',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ÉVALUER CE POINT DE VENTE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Stars Picker
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (starIdx) {
                            final double starValue = starIdx + 1.0;
                            final double currentRating = _orderRatings[order.id] ?? 5.0;
                            final isLit = starValue <= currentRating;
                            return IconButton(
                              onPressed: () {
                                setState(() {
                                  _orderRatings[order.id] = starValue;
                                });
                              },
                              icon: Icon(
                                isLit ? Icons.star : Icons.star_border,
                                color: isLit ? const Color(0xFFF59E0B) : const Color(0xFF27272A),
                                size: 28,
                              ),
                            );
                          }),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Comments field
                        TextField(
                          controller: _getHistoryController(order.id),
                          maxLines: 1,
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Votre avis sur la température de la nourriture, rapidité...',
                            hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 10),
                            filled: true,
                            fillColor: const Color(0xFF09090B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF27272A)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF27272A)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final text = _getHistoryController(order.id).text.trim();
                              if (text.isEmpty) return;
                              final rating = _orderRatings[order.id] ?? 5.0;
                              provider.submitRestaurantRating(order.id, order.restaurantId, rating, text);
                              _getHistoryController(order.id).clear();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF09090B),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Soumettre mon avis',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusLabel(OrderStatus status) {
    Color fg = Colors.grey;
    switch (status) {
      case OrderStatus.completed:
        fg = const Color(0xFF10B981);
        break;
      case OrderStatus.cancelled:
        fg = Colors.red;
        break;
      default:
        fg = const Color(0xFFF59E0B);
        break;
    }
    return Text(
      status.label.toUpperCase(),
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
    );
  }

  String _parseIsoDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
      final m = monthNames[dt.month - 1];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $m, ${dt.year} à ${h}h$min';
    } catch (e) {
      return isoString.split('T')[0];
    }
  }
}

// ─── Confetti CustomPainter ────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final int seed;

  _ConfettiPainter({required this.progress, required this.seed});

  static const int _count = 80;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final colors = [
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFA855F7),
      const Color(0xFFEF4444),
      Colors.white,
    ];

    for (int i = 0; i < _count; i++) {
      final startX = random.nextDouble() * size.width;
      final speed = 0.4 + random.nextDouble() * 0.6;
      final y = (progress * speed * size.height * 1.6) - (random.nextDouble() * size.height * 0.2);
      final x = startX + sin(progress * 6 + i) * 30;

      if (y < 0 || y > size.height) continue;

      final color = colors[random.nextInt(colors.length)];
      final paint = Paint()..color = color.withValues(alpha: (1.0 - progress * 0.8).clamp(0.0, 1.0));
      final w = 6.0 + random.nextDouble() * 6;
      final h = 3.0 + random.nextDouble() * 4;
      final angle = progress * 8 + random.nextDouble() * pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// Custom Painter drawing the stylized vector roadmap
class MapRoadmapPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final OrderStatus orderStatus;

  MapRoadmapPainter({
    required this.progress,
    required this.pulse,
    required this.orderStatus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF0E0E11)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF27272A).withValues(alpha: 0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final path = Path();
    final startPt = Offset(40, size.height - 40);
    final controlPt1 = Offset(size.width * 0.3, size.height * 0.85);
    final controlPt2 = Offset(size.width * 0.2, size.height * 0.3);
    final midPt = Offset(size.width * 0.5, size.height * 0.45);
    final controlPt3 = Offset(size.width * 0.8, size.height * 0.6);
    final endPt = Offset(size.width - 40, 40);

    path.moveTo(startPt.dx, startPt.dy);
    path.cubicTo(
      controlPt1.dx, controlPt1.dy,
      controlPt2.dx, controlPt2.dy,
      midPt.dx, midPt.dy,
    );
    path.quadraticBezierTo(controlPt3.dx, controlPt3.dy, endPt.dx, endPt.dy);

    final roadPaint = Paint()
      ..color = const Color(0xFF18181B)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, roadPaint);

    final roadBorderPaint = Paint()
      ..color = const Color(0xFF27272A)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, roadBorderPaint);
    canvas.drawPath(path, roadPaint);

    final neonPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, neonPaint);

    final Offset progressPt = _getPositionOnCubicPath(startPt, controlPt1, controlPt2, midPt, controlPt3, endPt, progress);

    final radarPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.15 + (pulse * 0.15))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(progressPt, 12 + (pulse * 8), radarPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(progressPt, 5.0, dotPaint);

    final startDotPaint = Paint()
      ..color = const Color(0xFFE4E4E7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPt, 4.0, startDotPaint);

    final endDotPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endPt, 5.0, endDotPaint);

    if (orderStatus == OrderStatus.readyForPickup) {
      final kitchenRadarPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.1 + (pulse * 0.15))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPt, 10 + (pulse * 10), kitchenRadarPaint);
    }
  }

  Offset _getPositionOnCubicPath(Offset p0, Offset p1, Offset p2, Offset p3, Offset p4, Offset p5, double t) {
    if (t < 0.5) {
      final double localT = t * 2.0;
      final double u = 1.0 - localT;
      final double tt = localT * localT;
      final double uu = u * u;
      final double uuu = uu * u;
      final double ttt = tt * localT;

      final double x = uuu * p0.dx + 3.0 * uu * localT * p1.dx + 3.0 * u * tt * p2.dx + ttt * p3.dx;
      final double y = uuu * p0.dy + 3.0 * uu * localT * p1.dy + 3.0 * u * tt * p2.dy + ttt * p3.dy;
      return Offset(x, y);
    } else {
      final double localT = (t - 0.5) * 2.0;
      final double u = 1.0 - localT;
      final double tt = localT * localT;
      final double uu = u * u;

      final double x = uu * p3.dx + 2.0 * u * localT * p4.dx + tt * p5.dx;
      final double y = uu * p3.dy + 2.0 * u * localT * p4.dy + tt * p5.dy;
      return Offset(x, y);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
