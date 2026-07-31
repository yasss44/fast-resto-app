import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models/resto_stats.dart';

class StatsService {
  final ApiClient _api = ApiClient();

  Future<RestoStats> getRestaurantStats(int periodDays) async {
    final data = await _api.get(
      ApiConfig.stats,
      queryParams: {'period': periodDays.toString()},
    );
    return RestoStats.fromJson(data as Map<String, dynamic>);
  }

  Future<String> exportStats({required int periodDays}) async {
    final data = await _api.get(
      ApiConfig.statsExport,
      queryParams: {'period': periodDays.toString()},
    );
    if (data is String) return data;
    if (data is Map<String, dynamic>) {
      return data['csv'] as String? ?? data['data'] as String? ?? '';
    }
    return data.toString();
  }
}
