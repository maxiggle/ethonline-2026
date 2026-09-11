import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';

class AuthService {
  AuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  UserIdentity? _currentUser;
  UserIdentity? get currentUser => _currentUser;

  /// Authenticates with a Privy token (obtained from Google or Email OAuth).
  Future<UserIdentity> loginWithPrivy(String authToken) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: {'authToken': authToken},
    );

    final userData = response['user'] as Map<String, dynamic>;
    _currentUser = UserIdentity.fromJson(userData);
    _apiClient.setAuthToken(authToken);
    return _currentUser!;
  }

  /// Retrieves the current authenticated user's profile and embedded wallet address.
  Future<UserIdentity> getProfile() async {
    final response = await _apiClient.get('/auth/me');
    final userData = response['user'] as Map<String, dynamic>;
    _currentUser = UserIdentity.fromJson(userData);
    return _currentUser!;
  }

  /// Retrieves all autonomous agents supervised by the authenticated user.
  Future<List<AgentModel>> getAgents() async {
    final response = await _apiClient.get('/agents');
    final agentsList = response['agents'] as List<dynamic>? ?? [];
    return agentsList
        .map((item) => AgentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Binds an autonomous AI agent to the user's Safe and identity.
  Future<AgentModel> bindAgent({
    required String agentAddress,
    required String name,
    String? purpose,
    required String safeAddress,
    required String guardAddress,
    int chainId = 84532,
  }) async {
    final response = await _apiClient.post(
      '/agents/bind',
      data: {
        'agentAddress': agentAddress,
        'name': name,
        'purpose': purpose,
        'safeAddress': safeAddress,
        'guardAddress': guardAddress,
        'chainId': chainId,
      },
    );

    final agentData = response['agent'] as Map<String, dynamic>;
    return AgentModel.fromJson(agentData);
  }

  /// Clears the active session and authorization token.
  void logout() {
    _currentUser = null;
    _apiClient.setAuthToken(null);
  }
}
