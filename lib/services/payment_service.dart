import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

class StripeCheckoutSession {
  final String sessionId;
  final String url;

  StripeCheckoutSession({required this.sessionId, required this.url});

  factory StripeCheckoutSession.fromJson(Map<String, dynamic> json) {
    return StripeCheckoutSession(
      sessionId: json['sessionId'] as String,
      url: json['url'] as String,
    );
  }
}

class PaymentService {
  final ApiClient _api = ApiClient();

  Future<StripeCheckoutSession> createCheckoutSession({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required int userWalkTimeMin,
    String? groupId,
    FulfillmentType fulfillmentType = FulfillmentType.pickup,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final data = await _api.post(
      ApiConfig.createCheckoutSession,
      body: {
        'restaurantId': restaurantId,
        'items': items,
        'userWalkTimeMin': userWalkTimeMin,
        if (groupId != null) 'groupId': groupId,
        'fulfillmentType': fulfillmentType.apiValue,
        if (fulfillmentType == FulfillmentType.delivery) ...{
          'deliveryAddress': deliveryAddress,
          if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
          if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
        },
      },
    );
    return StripeCheckoutSession.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> confirmCheckoutSession(String sessionId) async {
    final data = await _api.post(ApiConfig.confirmCheckoutSession(sessionId), body: {});
    return Order.fromApiJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createConnectAccountLink() async {
    final data = await _api.post(ApiConfig.stripeConnectAccountLink, body: {});
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConnectStatus() async {
    final data = await _api.get(ApiConfig.stripeConnectStatus);
    return data as Map<String, dynamic>;
  }
}
