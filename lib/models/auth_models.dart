class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String role;
  final String? driverType;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.role,
    this.driverType,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'phone': phone,
        if (driverType != null) 'driverType': driverType,
      };
}

class AuthResponse {
  final String token;
  final UserData user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        user: UserData.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class UserData {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role;
  final int points;
  final Map<String, dynamic>? restaurant;
  final DriverProfileData? driverProfile;

  UserData({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.points,
    this.restaurant,
    this.driverProfile,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String,
        points: json['points'] as int? ?? 0,
        restaurant: json['restaurant'] as Map<String, dynamic>?,
        driverProfile: json['driverProfile'] is Map<String, dynamic>
            ? DriverProfileData.fromJson(json['driverProfile'] as Map<String, dynamic>)
            : null,
      );

  bool get isRestaurant => role == 'RESTAURANT';
  bool get isClient => role == 'CLIENT';
  bool get isLivreur => role == 'LIVREUR';
}

class DriverProfileData {
  final String id;
  final String type;
  final bool isOnline;
  final bool isPaused;
  final String timezone;
  final List<Map<String, dynamic>> schedules;

  const DriverProfileData({
    required this.id,
    required this.type,
    required this.isOnline,
    required this.isPaused,
    required this.timezone,
    this.schedules = const [],
  });

  factory DriverProfileData.fromJson(Map<String, dynamic> json) => DriverProfileData(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'OCCASIONAL',
        isOnline: json['isOnline'] as bool? ?? false,
        isPaused: json['isPaused'] as bool? ?? false,
        timezone: json['timezone'] as String? ?? 'Europe/Paris',
        schedules: (json['schedules'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}
