import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

class ReviewService {
  final ApiClient _api = ApiClient();

  Future<List<Review>> listReviews(String restaurantId) async {
    final data = await _api.get(ApiConfig.reviewsByRestaurant(restaurantId));
    final list = (data as List<dynamic>)
        .map((e) => Review.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Review> createReview({
    required String restaurantId,
    required double rating,
    required String comment,
  }) async {
    final body = {
      'rating': rating,
      'comment': comment,
    };
    final data = await _api.post(
      ApiConfig.reviewsByRestaurant(restaurantId),
      body: body,
    );
    return Review.fromApiJson(data as Map<String, dynamic>);
  }
}
