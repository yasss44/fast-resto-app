import '../api/api_client.dart';
import '../api/api_config.dart';

class DeliveryService {
  final ApiClient _client = ApiClient();

  /// Get available deliveries
  Future<List<dynamic>> getAvailableDeliveries() async {
    final response = await _client.get(ApiConfig.availableDeliveries);
    return response as List<dynamic>;
  }

  /// Get driver's active delivery
  Future<Map<String, dynamic>?> getMyActiveDelivery() async {
    final response = await _client.get(ApiConfig.activeDelivery);
    if (response == null) return null;
    return response as Map<String, dynamic>;
  }

  /// Accept a delivery offer
  Future<Map<String, dynamic>> acceptDelivery(String id) async {
    final response = await _client.post(ApiConfig.acceptDelivery(id), body: {});
    return response as Map<String, dynamic>;
  }

  /// Update delivery status (AT_RESTAURANT, PICKED_UP, DELIVERED, CANCELLED)
  Future<Map<String, dynamic>> updateDeliveryStatus(String id, String status) async {
    final response = await _client.patch(ApiConfig.updateDeliveryStatus(id), body: {'status': status});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDriverProfile() async {
    final response = await _client.get(ApiConfig.driverProfile);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAvailability({
    bool? isOnline,
    bool? isPaused,
  }) async {
    final response = await _client.patch(
      ApiConfig.driverAvailability,
      body: {
        if (isOnline != null) 'isOnline': isOnline,
        if (isPaused != null) 'isPaused': isPaused,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> replaceSchedules({
    required String timezone,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final response = await _client.patch(
      ApiConfig.driverSchedules,
      body: {'timezone': timezone, 'schedules': schedules},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrderDelivery(String orderId) async {
    final response = await _client.get(ApiConfig.orderDelivery(orderId));
    return response as Map<String, dynamic>;
  }

}
