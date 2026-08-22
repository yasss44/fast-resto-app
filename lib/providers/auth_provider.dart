import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

enum AuthState { idle, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.idle;
  UserData? _user;
  String? _error;

  AuthState get state => _state;
  UserData? get user => _user;
  String? get error => _error;
  bool get isLoggedIn => _state == AuthState.authenticated && _user != null;
  bool get isRestaurant => _user?.isRestaurant ?? false;
  bool get isLivreur => _user?.isLivreur ?? false;

  /// Try auto-login on app start using stored token
  Future<void> autoLogin() async {
    _state = AuthState.loading;
    notifyListeners();

    await ApiClient().init();
    if (!ApiClient().isAuthenticated) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final me = await AuthService()
          .getMe()
          .timeout(const Duration(seconds: 4));
      _user = me;
      _state = AuthState.authenticated;
    } catch (_) {
      await ApiClient().setToken(null);
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService().login(
        LoginRequest(email: email, password: password),
      );
      await ApiClient().setToken(response.token);
      _user = response.user;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? driverType,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService().register(
        RegisterRequest(
          email: email,
          password: password,
          name: name,
          phone: phone,
          role: role,
          driverType: driverType,
        ),
      );
      await ApiClient().setToken(response.token);
      _user = response.user;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Notify backend to invalidate token (best-effort)
    try {
      await AuthService().logout();
    } catch (_) {
      // Proceed with local logout even if API call fails
    }
    await ApiClient().clearSecureData();
    _user = null;
    _state = AuthState.unauthenticated;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    final msg = e.toString();
    // Clean up common exception wrappers
    if (msg.contains('ApiException(')) {
      final start = msg.indexOf('): ') + 3;
      if (start < msg.length) return msg.substring(start);
    }
    if (msg.contains('ValidationException(')) {
      final start = msg.indexOf('): ') + 3;
      if (start < msg.length) return msg.substring(start);
    }
    return msg;
  }
}
