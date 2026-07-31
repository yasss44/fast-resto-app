import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

class OrderService {
  final ApiClient _api = ApiClient();

  Future<List<Order>> getMyOrders() async {
    final data = await _api.get(ApiConfig.myOrders);
    final list = (data as List<dynamic>)
        .map((e) => Order.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<Order>> getRestaurantOrders() async {
    final data = await _api.get(ApiConfig.restaurantOrders);
    final list = (data as List<dynamic>)
        .map((e) => Order.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Order> getOrder(String orderId) async {
    final data = await _api.get(ApiConfig.order(orderId));
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  Future<Order> placeOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required int userWalkTimeMin,
  }) async {
    final body = {
      'restaurantId': restaurantId,
      'items': items,
      'userWalkTimeMin': userWalkTimeMin,
    };
    final data = await _api.post(ApiConfig.orders, body: body);
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  Future<void> cancelOrder(String orderId) async {
    await _api.post(ApiConfig.cancelOrder(orderId));
  }

  Future<Order> updateOrderStatus(String orderId, String status) async {
    final data = await _api.patch(
      ApiConfig.updateOrderStatus(orderId),
      body: {'status': status},
    );
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  Future<Order> updateTracking({
    required String orderId,
    required double gpsProgress,
    required double latitude,
    required double longitude,
    bool? isReadyAtEntrance,
  }) async {
    final data = await _api.patch(
      ApiConfig.updateOrderTracking(orderId),
      body: {
        'gpsProgress': gpsProgress,
        'latitude': latitude,
        'longitude': longitude,
        if (isReadyAtEntrance != null) 'isReadyAtEntrance': isReadyAtEntrance,
      },
    );
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  Future<Order> verifyPickup({
    required String orderId,
    required String pickupToken,
  }) async {
    final data = await _api.post(
      ApiConfig.verifyPickup(orderId),
      body: {'pickupToken': pickupToken},
    );
    return Order.fromApiJson(data as Map<String, dynamic>);
  }
}
