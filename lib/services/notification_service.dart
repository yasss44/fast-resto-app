import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<List<PushNotification>> listNotifications() async {
    final data = await _api.get(ApiConfig.notifications);
    final list = (data as List<dynamic>)
        .map((e) => PushNotification.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<void> markAsRead(String id) async {
    await _api.patch(ApiConfig.readNotification(id));
  }

  Future<void> markAllAsRead() async {
    await _api.post(ApiConfig.readAll);
  }

  Future<void> deleteNotification(String id) async {
    await _api.delete(ApiConfig.deleteNotification(id));
  }

  Future<void> clearAll() async {
    await _api.delete(ApiConfig.notifications);
  }
}
