import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';

class Chapter2ApiService {
  Chapter2ApiService({ApiClient? apiClient, String? baseUrl})
    : _client = apiClient ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _client;

  Future<List<TreasuryAction>> fetchActions({
    TreasuryActionStatus? status,
  }) async {
    final query = status != null ? {'status': status.toServerString()} : null;
    final data = await _client.get('/actions', queryParameters: query);
    if (data is List) {
      return data
          .map((item) => TreasuryAction.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<TreasuryMandate> fetchMandate() async {
    final data = await _client.get('/mandates/active');
    return TreasuryMandate.fromJson(data as Map<String, dynamic>);
  }
}
