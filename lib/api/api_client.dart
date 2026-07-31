import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'api_exceptions.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'fast_api_token';

  String? _token;

  /// Called on 401 responses to redirect to login
  static void Function()? onUnauthorized;

  Future<void> init() async {
    _token = await _secureStorage.read(key: _tokenKey);
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> setToken(String? token) async {
    _token = token;
    if (token != null) {
      await _secureStorage.write(key: _tokenKey, value: token);
    } else {
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  /// Clear all secure stored data (used on logout)
  Future<void> clearSecureData() async {
    await _secureStorage.deleteAll();
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .post(uri, headers: _headers, body: body != null ? json.encode(body) : null)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .patch(uri, headers: _headers, body: body != null ? json.encode(body) : null)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http
        .put(uri, headers: _headers, body: body != null ? json.encode(body) : null)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.delete(uri, headers: _headers).timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? json.decode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw UnauthorizedException(body?['error'] ?? 'Non autorisé');
    }

    if (response.statusCode == 404) {
      throw NotFoundException(body?['error'] ?? 'Ressource non trouvée');
    }

    if (response.statusCode == 429) {
      throw ApiException(
        body?['error'] ?? 'Trop de requêtes. Réessayez plus tard.',
        response.statusCode,
      );
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      throw ValidationException(
        body?['error'] ?? 'Erreur de validation',
        body?['details'],
      );
    }

    throw ApiException(
      body?['error'] ?? 'Erreur serveur',
      response.statusCode,
    );
  }
}
