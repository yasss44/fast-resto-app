import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

class RestaurantService {
  final ApiClient _api = ApiClient();

  Future<List<Restaurant>> listRestaurants({
    String? category,
    String? search,
    String? dietary,
  }) async {
    final params = <String, String>{};
    if (category != null && category != 'all') params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (dietary != null) params['dietary'] = dietary;

    final data = await _api.get(ApiConfig.restaurants, queryParams: params.isNotEmpty ? params : null);
    final list = (data as List<dynamic>)
        .map((e) => Restaurant.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Restaurant> getRestaurant(String id) async {
    final data = await _api.get(ApiConfig.restaurant(id));
    return Restaurant.fromApiJson(data as Map<String, dynamic>);
  }

  Future<List<MenuItem>> listMenuItems(String restaurantId) async {
    final data = await _api.get(ApiConfig.menuByRestaurant(restaurantId));
    final list = (data as List<dynamic>)
        .map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<MenuItem> createMenuItem(String restaurantId, Map<String, dynamic> itemData) async {
    final data = await _api.post(ApiConfig.menuByRestaurant(restaurantId), body: itemData);
    return MenuItem.fromApiJson(data as Map<String, dynamic>);
  }

  Future<List<MenuItem>> scanMenu(String restaurantId, String imageBase64) async {
    final data = await _api.post(
      ApiConfig.scanMenu(restaurantId),
      body: {'imageBase64': imageBase64},
    );
    final list = (data as List<dynamic>)
        .map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Map<String, dynamic>> getMyRestaurant() async {
    final data = await _api.get(ApiConfig.myRestaurant);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRestaurant(String id, Map<String, dynamic> body) async {
    final data = await _api.patch(ApiConfig.updateRestaurant(id), body: body);
    return data as Map<String, dynamic>;
  }
}
