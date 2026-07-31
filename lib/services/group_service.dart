import '../api/api_client.dart';
import '../api/api_config.dart';

class GroupService {
  final ApiClient _client = ApiClient();

  /// Create a new group
  Future<Map<String, dynamic>> createGroup({String? restaurantId}) async {
    final body = <String, dynamic>{};
    if (restaurantId != null) body['restaurantId'] = restaurantId;
    final response = await _client.post(ApiConfig.groups, body: body);
    return response as Map<String, dynamic>;
  }

  /// Join an existing group by code
  Future<Map<String, dynamic>> joinGroup(String code) async {
    final response = await _client.post(ApiConfig.joinGroup, body: {'code': code});
    return response as Map<String, dynamic>;
  }

  /// Get all my active groups
  Future<List<dynamic>> getMyGroups() async {
    final response = await _client.get(ApiConfig.myGroups);
    return response as List<dynamic>;
  }

  /// Get a specific group by ID
  Future<Map<String, dynamic>> getGroup(String id) async {
    final response = await _client.get(ApiConfig.group(id));
    return response as Map<String, dynamic>;
  }

  /// Leave a group
  Future<Map<String, dynamic>> leaveGroup(String id) async {
    final response = await _client.post(ApiConfig.leaveGroup(id), body: {});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMyPart(
    String id, {
    required int itemsCount,
    required double total,
    required bool isReady,
  }) async {
    final response = await _client.patch(
      ApiConfig.updateGroupMember(id),
      body: {'itemsCount': itemsCount, 'total': total, 'isReady': isReady},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lockGroup(String id) async {
    final response = await _client.post(ApiConfig.lockGroup(id), body: {});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitGroup(String id) async {
    final response = await _client.post(ApiConfig.submitGroup(id), body: {});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveCart(
    String id, {
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _client.put(
      ApiConfig.groupCart(id),
      body: {'items': items},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCart(String id) async {
    final response = await _client.get(ApiConfig.groupCart(id));
    return response as Map<String, dynamic>;
  }
}
