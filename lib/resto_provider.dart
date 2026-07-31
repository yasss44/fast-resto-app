import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services/order_service.dart';
import 'services/menu_service.dart';
import 'services/stats_service.dart';
import 'models/resto_stats.dart';
import 'api/api_exceptions.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

class RestoProvider extends ChangeNotifier {
  RestaurantSettings? _settings;
  bool _isRgpdAccepted = false;
  bool _isTutorialDone = false;
  bool _skipSplash = false;
  bool _isRushMode = false;
  String _theme = 'dark'; // data-theme equivalent

  // Orders specific to Resto
  List<Order> _restoOrders = [];

  // Menu
  List<MenuItem> _menu = [];
  bool _menuLoading = false;

  // Restaurant analytics
  RestoStats? _stats;
  bool _statsLoading = false;
  String? _statsError;
  int _statsPeriodDays = 7;
  int _statsRequestId = 0;

  // API state
  bool _isApiLoaded = false;
  String? _restaurantId;
  String? _error;
  Timer? _pollTimer;
  final _orderService = OrderService();
  final _menuService = MenuService();
  final _statsService = StatsService();

  // Getters
  RestaurantSettings? get settings => _settings;
  bool get isRgpdAccepted => _isRgpdAccepted;
  bool get isTutorialDone => _isTutorialDone;
  bool get skipSplash => _skipSplash;
  bool get isRushMode => _isRushMode;
  String get theme => _theme;
  List<Order> get restoOrders => _restoOrders;
  List<MenuItem> get menu => _menu;
  bool get menuLoading => _menuLoading;
  RestoStats? get stats => _stats;
  bool get statsLoading => _statsLoading;
  String? get statsError => _statsError;
  int get statsPeriodDays => _statsPeriodDays;
  bool get isApiLoaded => _isApiLoaded;
  String? get restaurantId => _restaurantId;
  String? get error => _error;

  RestoProvider() {
    _loadState();
  }

  /// Clear error so UI can dismiss it
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load orders from API and start polling
  Future<void> loadFromApi({String? restaurantId}) async {
    _restaurantId = restaurantId;
    await Future.wait([refreshOrders(), loadMenu()]);
    _isApiLoaded = true;
    _startPolling();
    notifyListeners();
  }

  // ─── Menu CRUD ──────────────────────────────────────────────

  Future<void> loadMenu() async {
    if (_restaurantId == null) return;
    _menuLoading = true;
    notifyListeners();
    try {
      _menu = await _menuService.getMenuByRestaurant(_restaurantId!);
      _error = null;
    } catch (e) {
      _error = _extractErrorMessage(e);
    }
    _menuLoading = false;
    notifyListeners();
  }

  Future<void> loadStats({int? periodDays}) async {
    final nextPeriod = periodDays ?? _statsPeriodDays;
    if (nextPeriod != 7 && nextPeriod != 30 && nextPeriod != 90) return;

    _statsPeriodDays = nextPeriod;
    _statsLoading = true;
    _statsError = null;
    final requestId = ++_statsRequestId;
    notifyListeners();

    try {
      final result = await _statsService.getRestaurantStats(nextPeriod);
      if (requestId != _statsRequestId) return;
      _stats = result;
    } catch (e) {
      if (requestId != _statsRequestId) return;
      _statsError = _extractErrorMessage(e);
    } finally {
      if (requestId == _statsRequestId) {
        _statsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<MenuItem?> addMenuItem(Map<String, dynamic> body) async {
    if (_restaurantId == null) return null;
    try {
      final item = await _menuService.createItem(_restaurantId!, body);
      _menu.add(item);
      notifyListeners();
      return item;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateMenuItem(String id, Map<String, dynamic> body) async {
    try {
      final updated = await _menuService.updateItem(id, body);
      final idx = _menu.indexWhere((m) => m.id == id);
      if (idx != -1) _menu[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    try {
      await _menuService.deleteItem(id);
      _menu.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleMenuItemAvailability(String id, bool available) async {
    // Optimistic update
    final idx = _menu.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _menu[idx] = _menu[idx].copyWith(available: available);
      notifyListeners();
    }
    try {
      await _menuService.toggleAvailability(id, available);
    } catch (e) {
      // Rollback on failure
      if (idx != -1) {
        _menu[idx] = _menu[idx].copyWith(available: !available);
      }
      _error = _extractErrorMessage(e);
      notifyListeners();
    }
  }

  /// Fetch the latest orders from the API
  Future<void> refreshOrders() async {
    try {
      final orders = await _orderService.getRestaurantOrders();
      _restoOrders = orders;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshOrders();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Settings
    final settingsJson = prefs.getString('fast_resto_settings');
    if (settingsJson != null) {
      try {
        _settings = RestaurantSettings.fromJson(json.decode(settingsJson));
      } catch (e) {
        _settings = null;
      }
    }

    _isRgpdAccepted = prefs.getBool('fast_rgpd_accepted') ?? false;
    _isTutorialDone = prefs.getBool('fast_tutorial_done') ?? false;
    _skipSplash = prefs.getBool('fast_skip_splash') ?? false;
    _isRushMode = prefs.getBool('fast_rush') ?? false;
    _theme = prefs.getString('fast_r_theme') ?? 'dark';

    notifyListeners();
  }

  Future<void> updateSettings(RestaurantSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'fast_resto_settings',
      json.encode(settings.toJson()),
    );
    notifyListeners();
  }

  Future<void> acceptRgpd() async {
    _isRgpdAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_rgpd_accepted', true);
    notifyListeners();
  }

  Future<void> completeTutorial() async {
    _isTutorialDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_tutorial_done', true);
    notifyListeners();
  }

  Future<void> skipSplashLogic() async {
    _skipSplash = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_skip_splash', true);
    notifyListeners();
  }

  Future<void> toggleRushMode() async {
    _isRushMode = !_isRushMode;

    // Sync with API
    if (_isApiLoaded) {
      try {
        await ApiClient().post(ApiConfig.toggleRush);
      } catch (e) {
        _error = _extractErrorMessage(e);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_rush', _isRushMode);
    notifyListeners();
  }

  Future<void> clearAllSettingsAndRestart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fast_resto_settings');
    await prefs.remove('fast_rgpd_accepted');
    await prefs.remove('fast_tutorial_done');
    await prefs.remove('fast_skip_splash');

    _settings = null;
    _isRgpdAccepted = false;
    _isTutorialDone = false;
    _skipSplash = false;

    notifyListeners();
  }

  String _extractErrorMessage(dynamic e) {
    if (e is ApiException) return e.message;
    if (e is String) return e;
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
