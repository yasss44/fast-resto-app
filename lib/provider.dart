// lib/provider.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'services/restaurant_service.dart';
import 'services/order_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/review_service.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'services/payment_service.dart';
import 'api/api_exceptions.dart';

const _pendingStripeSessionKey = 'fast_pending_stripe_session_id';
const _activeGroupIdKey = 'fast_active_group_id';
const _activeGroupCodeKey = 'fast_active_group_code';

class CategoryItem {
  final String id;
  final String name;
  final String icon;

  CategoryItem({required this.id, required this.name, required this.icon});
}

class FASTProvider extends ChangeNotifier {
  List<Restaurant> _restaurants = [];
  String _selectedCategory = 'all';
  String _searchKeyword = '';
  List<DietaryPreference> _selectedDietary = [];
  List<CartItem> _cart = [];
  List<PushNotification> _notifications = [];
  List<Order> _orders = [];
  Restaurant? _selectedRestaurant;
  String? _activeGroupId;
  String? _activeGroupCode;
  FulfillmentType _fulfillmentType = FulfillmentType.pickup;
  String _deliveryAddress = '';
  double? _deliveryLatitude;
  double? _deliveryLongitude;

  // UI status
  String _currentScreen = 'home';
  String? _activeOrderId;
  bool _isNotifOpen = false;
  bool _showDietarySlider = false;
  Map<String, String>? _toast;

  // Surprise Me animation states
  bool _isSurpriseMeRolling = false;
  Restaurant? _surpriseMeRolledRestaurant;

  // User profile
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  int _userPoints = 0;
  ThemeMode _themeMode = ThemeMode.dark;

  // User location
  LatLng? _userLocation;
  bool _locationLoading = false;

  // API state & errors
  bool _isLoading = false;
  String? _error;
  String? _orderError;

  // Services
  final _restaurantService = RestaurantService();
  final _orderService = OrderService();
  final _notificationService = NotificationService();
  final _reviewService = ReviewService();
  final _authService = AuthService();
  final _groupService = GroupService();
  final _paymentService = PaymentService();

  // Periodic order polling
  Timer? _orderPollTimer;

  // Getters
  List<Restaurant> get restaurants => _restaurants;
  String get selectedCategory => _selectedCategory;
  String get searchKeyword => _searchKeyword;
  List<DietaryPreference> get selectedDietary => _selectedDietary;
  List<CartItem> get cart => _cart;
  List<PushNotification> get notifications => _notifications;
  List<Order> get orders => _orders;
  Restaurant? get selectedRestaurant => _selectedRestaurant;
  String? get activeGroupId => _activeGroupId;
  String? get activeGroupCode => _activeGroupCode;
  FulfillmentType get fulfillmentType => _fulfillmentType;
  String get deliveryAddress => _deliveryAddress;
  double? get deliveryLatitude => _deliveryLatitude;
  double? get deliveryLongitude => _deliveryLongitude;
  String get currentScreen => _currentScreen;
  String? get activeOrderId => _activeOrderId;
  bool get isNotifOpen => _isNotifOpen;
  bool get showDietarySlider => _showDietarySlider;
  Map<String, String>? get toast => _toast;
  bool get isSurpriseMeRolling => _isSurpriseMeRolling;
  Restaurant? get surpriseMeRolledRestaurant => _surpriseMeRolledRestaurant;

  // Profile getters
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;
  int get userPoints => _userPoints;
  ThemeMode get themeMode => _themeMode;
  String get userInitial => _userName.isNotEmpty ? _userName[0].toUpperCase() : '?';

  // Points from API (synced via AuthProvider.getMe)
  String get membershipLevel {
    final pts = _userPoints;
    if (pts >= 200) return 'FAST Gold';
    if (pts >= 80) return 'Membre FAST';
    return 'Nouveau FAST';
  }

  bool get hasUnreadNotifications => _notifications.any((n) => !n.isRead);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get orderError => _orderError;
  LatLng? get userLocation => _userLocation;
  bool get locationLoading => _locationLoading;

  /// Sync from AuthProvider after login
  void syncFromAuth({
    required String id,
    required String name,
    required String email,
    required String phone,
    int points = 0,
  }) {
    _userName = name;
    _userEmail = email;
    _userPhone = phone;
    _userPoints = points;
    notifyListeners();
  }

  void syncPoints(int points) {
    _userPoints = points;
    notifyListeners();
  }

  /// Clear error so UI can dismiss it
  void clearError() {
    _error = null;
    _orderError = null;
    notifyListeners();
  }

  /// Fetch user GPS location
  Future<void> fetchUserLocation() async {
    _locationLoading = true;
    notifyListeners();

    _userLocation = await LocationService.instance.getCurrentLocation();

    _locationLoading = false;
    notifyListeners();
  }

  /// Get real GPS distance from user to a restaurant (km)
  double getRealDistance(Restaurant rest) {
    if (_userLocation == null) return rest.distance;
    return LocationService.instance.calculateDistance(
      _userLocation!,
      LatLng(rest.latitude, rest.longitude),
    );
  }

  /// Load all data from the backend API
  Future<void> loadFromApi() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _restaurantService.listRestaurants(),
        _orderService.getMyOrders(),
        _notificationService.listNotifications(),
      ], eagerError: false);

      final restaurants = results[0] as List<Restaurant>;
      final orders = results[1] as List<Order>;
      final notifications = results[2] as List<PushNotification>;

      _restaurants = restaurants;
      _orders = orders;
      _notifications = notifications;
      // Fetch user location after data loads
      fetchUserLocation();
      // Start/stop order polling based on active orders
      syncOrderPolling();
      await Future.wait([
        _saveRestaurants(),
        _saveOrders(),
        _saveNotifications(),
      ]);
    } catch (e) {
      _error = _extractErrorMessage(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh just orders
  Future<void> refreshOrders() async {
    try {
      _orders = await _orderService.getMyOrders();
      await _saveOrders();
      notifyListeners();
    } catch (_) {}
  }

  /// Refresh orders and sync polling state
  Future<void> refreshOrdersAndSync() async {
    await refreshOrders();
    syncOrderPolling();
  }

  /// Start periodic polling for active orders and notifications (every 30s)
  void startOrderPolling() {
    _orderPollTimer?.cancel();
    _orderPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshOrdersAndSync();
      refreshNotifications();
    });
  }

  /// Stop periodic order polling
  void stopOrderPolling() {
    _orderPollTimer?.cancel();
    _orderPollTimer = null;
  }

  /// Start or stop polling based on whether there are active orders
  void syncOrderPolling() {
    final hasActive = _orders.any(
      (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
    );
    if (hasActive) {
      startOrderPolling();
    } else {
      stopOrderPolling();
    }
  }

  /// Refresh just notifications
  Future<void> refreshNotifications() async {
    try {
      _notifications = await _notificationService.listNotifications();
      await _saveNotifications();
      notifyListeners();
    } catch (_) {}
  }

  // Categories definition
  final List<CategoryItem> categories = [
    CategoryItem(id: 'all', name: 'Tous', icon: '🍽️'),
    CategoryItem(id: 'burger', name: 'Burgers', icon: '🍔'),
    CategoryItem(id: 'pizza', name: 'Italien', icon: '🍕'),
    CategoryItem(id: 'sushi', name: 'Asiatique', icon: '🍣'),
    CategoryItem(id: 'healthy', name: 'Bols', icon: '🥗'),
    CategoryItem(id: 'halal', name: 'Kebab', icon: '🥙'),
    CategoryItem(id: 'dessert', name: 'Desserts', icon: '🍰'),
  ];

  FASTProvider() {
    _initializeData();
  }

  // Load persistence and initial setup
  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load restaurants from SharedPreferences cache
    final savedRest = prefs.getString('fast_resto_restaurants');
    if (savedRest != null) {
      try {
        final List<dynamic> list = json.decode(savedRest);
        _restaurants = list.map((x) => Restaurant.fromJson(x)).toList();
      } catch (e) {
        _restaurants = [];
      }
    }

    // 2. Load orders
    final savedOrders = prefs.getString('fast_resto_orders');
    if (savedOrders != null) {
      try {
        final List<dynamic> list = json.decode(savedOrders);
        _orders = list.map((x) => Order.fromJson(x)).toList();
      } catch (e) {
        _orders = [];
      }
    } else {
      _orders = [];
    }

    // 3. Load notifications
    final savedNotifs = prefs.getString('fast_resto_notifications');
    if (savedNotifs != null) {
      try {
        final List<dynamic> list = json.decode(savedNotifs);
        _notifications = list.map((x) => PushNotification.fromJson(x)).toList();
      } catch (e) {
        _notifications = [];
      }
    }

    // 4. Load user profile
    _userName = prefs.getString('fast_user_name') ?? '';
    _userEmail = prefs.getString('fast_user_email') ?? '';
    _userPhone = prefs.getString('fast_user_phone') ?? '';
    _activeGroupId = prefs.getString(_activeGroupIdKey);
    _activeGroupCode = prefs.getString(_activeGroupCodeKey);
    final themePref = prefs.getString('fast_theme_mode') ?? 'dark';
    _themeMode = themePref == 'light'
        ? ThemeMode.light
        : themePref == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;

    notifyListeners();
    // NOTE: Simulation removed — order states are fully manual.
  }

  // Save to persistence
  Future<void> _saveRestaurants() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('fast_resto_restaurants', json.encode(_restaurants.map((x) => x.toJson()).toList()));
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('fast_resto_orders', json.encode(_orders.map((x) => x.toJson()).toList()));
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('fast_resto_notifications', json.encode(_notifications.map((x) => x.toJson()).toList()));
  }

  Future<void> updateProfile({String? name, String? email, String? phone}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (body.isEmpty) return;

    try {
      final user = await _authService.updateProfile(body);
      _userName = user.name;
      _userEmail = user.email;
      _userPhone = user.phone;
      _userPoints = user.points;
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('fast_user_name', _userName);
      prefs.setString('fast_user_email', _userEmail);
      prefs.setString('fast_user_phone', _userPhone);
      notifyListeners();
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.system) val = 'system';
    prefs.setString('fast_theme_mode', val);
    prefs.setBool('fast_theme_dark', mode != ThemeMode.light);
    notifyListeners();
  }

  void deleteAccount() {
    stopOrderPolling();
    _userName = '';
    _userEmail = '';
    _userPhone = '';
    _orders = [];
    _notifications = [];
    _cart = [];
    SharedPreferences.getInstance().then((prefs) {
      prefs.clear();
    });
    notifyListeners();
  }

  // Navigation and Filtering
  void navigateToScreen(String screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void selectRestaurant(String? id) {
    if (id == null) {
      _selectedRestaurant = null;
    } else {
      _selectedRestaurant = _restaurants.firstWhere((r) => r.id == id, orElse: () => _restaurants.first);
    }
    notifyListeners();
  }

  void setActiveGroup({
    required String? id,
    String? code,
    String? restaurantId,
  }) {
    _activeGroupId = id;
    _activeGroupCode = code;
    if (restaurantId != null && _restaurants.isNotEmpty) {
      _selectedRestaurant = _restaurants.firstWhere(
        (restaurant) => restaurant.id == restaurantId,
        orElse: () => _restaurants.first,
      );
    }
    SharedPreferences.getInstance().then((prefs) {
      if (id != null) {
        prefs.setString(_activeGroupIdKey, id);
        if (code != null) prefs.setString(_activeGroupCodeKey, code);
      } else {
        prefs.remove(_activeGroupIdKey);
        prefs.remove(_activeGroupCodeKey);
      }
    });
    notifyListeners();
  }

  void clearActiveGroup() {
    _activeGroupId = null;
    _activeGroupCode = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_activeGroupIdKey);
      prefs.remove(_activeGroupCodeKey);
    });
    notifyListeners();
  }

  void setCategory(String categoryId) {
    _selectedCategory = categoryId;
    notifyListeners();
  }

  void setKeyword(String keyword) {
    _searchKeyword = keyword;
    notifyListeners();
  }

  void toggleDietary(DietaryPreference pref) {
    if (_selectedDietary.contains(pref)) {
      _selectedDietary.remove(pref);
    } else {
      _selectedDietary.add(pref);
    }
    notifyListeners();
  }

  void resetFilters() {
    _selectedCategory = 'all';
    _searchKeyword = '';
    _selectedDietary = [];
    notifyListeners();
  }

  // Autocomplete Category Suggestion Chip Logic
  List<CategoryItem> getAutocompleteCategories() {
    if (_searchKeyword.isEmpty) return [];
    final kw = _searchKeyword.toLowerCase();
    return categories
        .where((c) => c.id != 'all' && c.name.toLowerCase().contains(kw))
        .toList();
  }

  // List filter logic
  List<Restaurant> getFilteredRestaurants() {
    return _restaurants.where((rest) {
      final matchesCategory = _selectedCategory == 'all' || rest.category == _selectedCategory;

      final kw = _searchKeyword.toLowerCase();
      final matchesSearch = rest.name.toLowerCase().contains(kw) ||
          rest.description.toLowerCase().contains(kw) ||
          rest.menu.any((item) =>
              item.name.toLowerCase().contains(kw) || item.description.toLowerCase().contains(kw));

      final matchesDietary = _selectedDietary.isEmpty ||
          _selectedDietary.every((pref) =>
              rest.dietaryOptions.contains(pref) ||
              rest.menu.any((item) => item.dietaryTags.contains(pref)));

      return matchesCategory && matchesSearch && matchesDietary;
    }).toList();
  }

  // Surprise Me logic - Slot Machine visual animation
  void triggerSurpriseMe(BuildContext context) {
    if (_restaurants.isEmpty || _isSurpriseMeRolling) return;

    _isSurpriseMeRolling = true;
    _currentScreen = 'home';
    notifyListeners();

    int ticks = 0;
    const totalTicks = 12; // 1.5 seconds roll with 125ms interval
    final rand = Random();

    Timer.periodic(const Duration(milliseconds: 125), (timer) {
      ticks++;
      // Select random restaurant to show in rolling ticker
      _surpriseMeRolledRestaurant = _restaurants[rand.nextInt(_restaurants.length)];
      notifyListeners();

      if (ticks >= totalTicks) {
        timer.cancel();
        _isSurpriseMeRolling = false;
        _selectedRestaurant = _surpriseMeRolledRestaurant;
        _currentScreen = 'restaurant';
        _surpriseMeRolledRestaurant = null;
        
        showToast(
          '🎯 Coup de surprise !',
          'Nous avons sélectionné ${_selectedRestaurant!.name} pour vous !',
        );
        notifyListeners();
      }
    });
  }

  // Cart Management
  double get cartSubtotal => _cart.fold(0.0, (sum, item) => sum + (item.menuItem.price * item.quantity));
  double get flatServiceFee => 1.50; // Constant flat fee
  double get cartDeliveryFee {
    if (_fulfillmentType != FulfillmentType.delivery || _cart.isEmpty) return 0;
    return _selectedRestaurant?.deliveryFee ?? 2.99;
  }
  double get cartTotal => _cart.isEmpty ? 0.0 : cartSubtotal + flatServiceFee + cartDeliveryFee;

  void setFulfillmentType(FulfillmentType type) {
    _fulfillmentType = type;
    notifyListeners();
  }

  void setDeliveryAddress(String address, {double? latitude, double? longitude}) {
    _deliveryAddress = address;
    _deliveryLatitude = latitude;
    _deliveryLongitude = longitude;
    notifyListeners();
  }
  int get cartCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  void addToCart(MenuItem item, int qty, List<String> selectedOptions, String allergyNotes) {
    final existingIndex = _cart.indexWhere((c) => c.menuItem.id == item.id);
    if (existingIndex > -1) {
      _cart[existingIndex].quantity += qty;
      // Merge any new selected options
      if (selectedOptions.isNotEmpty) {
        _cart[existingIndex].selectedOptions.addAll(selectedOptions);
      }
      if (allergyNotes.isNotEmpty) {
        _cart[existingIndex].allergyNotes = allergyNotes;
      }
    } else {
      _cart.add(CartItem(menuItem: item, quantity: qty, selectedOptions: selectedOptions, allergyNotes: allergyNotes));
    }
    showToast('Ajouté au panier ! 🛒', '${qty}x ${item.name} ajouté.');
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    _cart.removeWhere((c) => c.menuItem.id == itemId);
    notifyListeners();
  }

  void updateCartQuantity(String itemId, int qty) {
    if (qty <= 0) {
      removeFromCart(itemId);
      return;
    }
    final index = _cart.indexWhere((c) => c.menuItem.id == itemId);
    if (index > -1) {
      _cart[index].quantity = qty;
    }
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    notifyListeners();
  }

  void acceptPaidOrder(Order order) {
    final wasGroupOrder = _activeGroupId != null;
    _orders.removeWhere((existing) => existing.id == order.id);
    _orders.insert(0, order);
    _activeOrderId = order.id;
    clearCart();
    _currentScreen = wasGroupOrder ? 'commandes' : 'commandes';
    addNotification(
      'Paiement confirmé !',
      wasGroupOrder
          ? 'Votre part est payée et attend l’envoi du groupe.'
          : 'Votre commande Click & Collect chez ${order.restaurantName} a été enregistrée.',
      'success',
    );
    _saveOrders();
    syncOrderPolling();
    notifyListeners();
  }

  Future<void> syncGroupCartToServer() async {
    if (_activeGroupId == null || _cart.isEmpty) return;
    final items = _cart
        .map((c) => {
              'menuItemId': c.menuItem.id,
              'quantity': c.quantity,
              'selectedOptions': c.selectedOptions,
              'allergyNotes': c.allergyNotes,
            })
        .toList();
    await _groupService.saveCart(_activeGroupId!, items: items);
  }

  static Future<void> savePendingStripeSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingStripeSessionKey, sessionId);
  }

  static Future<String?> loadPendingStripeSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingStripeSessionKey);
  }

  static Future<void> clearPendingStripeSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingStripeSessionKey);
  }

  Future<bool> confirmStripeCheckout(String sessionId) async {
    try {
      final order = await _paymentService.confirmCheckoutSession(sessionId);
      await FASTProvider.clearPendingStripeSession();
      acceptPaidOrder(order);
      return true;
    } catch (e) {
      _orderError = _extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  void updateOrderTrackingLocally(String orderId, {double? gpsProgress, bool? isReadyAtEntrance}) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    if (gpsProgress != null) _orders[idx].gpsProgress = gpsProgress;
    if (isReadyAtEntrance != null) _orders[idx].isReadyAtEntrance = isReadyAtEntrance;
    notifyListeners();
  }
  Future<void> placeOrder(int walkTimeMinutes) async {
    if (_selectedRestaurant == null || _cart.isEmpty) return;

    _orderError = null;
    notifyListeners();

    try {
      final items = _cart
          .map((c) => {
                'menuItemId': c.menuItem.id,
                'quantity': c.quantity,
                'selectedOptions': c.selectedOptions.toString(),
                'allergyNotes': c.allergyNotes,
              })
          .toList();

      final order = await _orderService.placeOrder(
        restaurantId: _selectedRestaurant!.id,
        items: items,
        userWalkTimeMin: walkTimeMinutes,
      );

      _orders.insert(0, order);
      _activeOrderId = order.id;
      clearCart();
      _currentScreen = 'commandes';

      addNotification(
        'Commande passée ! ⚡',
        'Votre commande Click & Collect chez ${_selectedRestaurant!.name} a été enregistrée.',
        'success',
      );

      await _saveOrders();
      syncOrderPolling();
      notifyListeners();
    } catch (e) {
      _orderError = _extractErrorMessage(e);
      showToast('Erreur de commande', _orderError!);
      notifyListeners();
    }
  }

  // Simulation intentionally removed.
  // Order state transitions (placed → preparing → ready) are
  // controlled manually by the restaurant user through the API.

  // Cancel order via API — no local fallback
  Future<bool> cancelOrder(String orderId) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return false;

    _orderError = null;

    try {
      await _orderService.cancelOrder(orderId);
      final order = _orders[idx];
      order.status = OrderStatus.cancelled;
      await _saveOrders();
      notifyListeners();
      return true;
    } catch (e) {
      _orderError = _extractErrorMessage(e);
      showToast('Erreur d\'annulation', _orderError!);
      notifyListeners();
      return false;
    }
  }

  // Submit reviews via API — no local fallback
  Future<void> submitRestaurantRating(String orderId, String restaurantId, double rating, String comment) async {
    _error = null;

    try {
      await _reviewService.createReview(
        restaurantId: restaurantId,
        rating: rating,
        comment: comment,
      );

      final oIdx = _orders.indexWhere((o) => o.id == orderId);
      if (oIdx > -1) {
        _orders[oIdx].userRatingSubmitted = true;
        await _saveOrders();
      }

      addNotification(
        'Avis soumis ! ⭐',
        'Merci pour votre évaluation.',
        'success',
      );
      notifyListeners();
    } catch (e) {
      _error = _extractErrorMessage(e);
      showToast('Erreur d\'envoi', _error!);
      notifyListeners();
    }
  }

  // Toast / Notifications actions
  void addNotification(String title, String body, String type) {
    final newNotif = PushNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      timestamp: _formattedTimeNow(),
      isRead: false,
      type: type,
    );

    _notifications.insert(0, newNotif);
    _toast = {'title': title, 'body': body};
    _saveNotifications();
    notifyListeners();
  }

  void showToast(String title, String body) {
    _toast = {'title': title, 'body': body};
    notifyListeners();
  }

  void dismissToast() {
    _toast = null;
    notifyListeners();
  }

  void toggleNotifPane(bool open) {
    _isNotifOpen = open;
    if (open) {
      for (var n in _notifications) {
        n.isRead = true;
      }
      _saveNotifications();
    }
    notifyListeners();
  }

  void toggleDietarySlider(bool show) {
    _showDietarySlider = show;
    notifyListeners();
  }

  void clearNotifications() {
    _notifications = [];
    _saveNotifications();
    notifyListeners();
  }

  String _formattedTimeNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _extractErrorMessage(dynamic e) {
    if (e is ApiException) return e.message;
    if (e is String) return e;
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
