import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models/auth_models.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<AuthResponse> login(LoginRequest request) async {
    final data = await _api.post(ApiConfig.login, body: request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final data = await _api.post(ApiConfig.register, body: request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<UserData> getMe() async {
    final data = await _api.get(ApiConfig.me);
    // Backend returns user data at root level
    if (data is Map<String, dynamic> && data.containsKey('id')) {
      return UserData.fromJson(data);
    }
    // Fallback for nested format
    return UserData.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _api.post(ApiConfig.logout);
  }

  Future<UserData> updateProfile(Map<String, dynamic> body) async {
    final data = await _api.patch(ApiConfig.updateProfile, body: body);
    if (data is Map<String, dynamic> && data.containsKey('id')) {
      return UserData.fromJson(data);
    }
    return UserData.fromJson(data['user'] as Map<String, dynamic>);
  }
}
