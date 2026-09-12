import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';
import 'package:chapter2/features/auth/services/privy_manager.dart';

class AuthService {
  AuthService({
    required ApiClient apiClient,
    PrivyManager? privyManager,
  })  : _apiClient = apiClient,
        _privyManager = privyManager ?? PrivyManager();

  final ApiClient _apiClient;
  final PrivyManager _privyManager;

  UserIdentity? _currentUser;
  UserIdentity? get currentUser => _currentUser;

  /// Authenticates with Google via Privy OAuth popup/sheet.
  Future<UserIdentity> loginWithGoogle() async {
    final privyAuth = await _privyManager.loginWithGoogle();
    return loginWithPrivy(
      privyAuth.authToken,
      email: privyAuth.email,
      name: privyAuth.name,
      walletAddress: privyAuth.walletAddress,
    );
  }

  /// Authenticates with a Privy token.
  Future<UserIdentity> loginWithPrivy(
    String authToken, {
    String? email,
    String? name,
    String? walletAddress,
  }) async {
    final payload = <String, dynamic>{'authToken': authToken};
    if (email != null) payload['email'] = email;
    if (name != null) payload['name'] = name;
    if (walletAddress != null) payload['walletAddress'] = walletAddress;

    _apiClient.setAuthToken(authToken);

    final response = await _apiClient.post(
      '/auth/login',
      data: payload,
    );

    final userData = response['user'] as Map<String, dynamic>;
    final isNew = response['isNewUser'] as bool? ?? false;
    _currentUser = UserIdentity.fromJson(userData, isNewUser: isNew);
    return _currentUser!;
  }

  /// Attempts to restore an existing authenticated session from Privy.
  Future<UserIdentity?> checkSession() async {
    try {
      final session = await _privyManager.getCurrentSession();
      if (session != null) {
        return await loginWithPrivy(
          session.authToken,
          email: session.email,
          name: session.name,
          walletAddress: session.walletAddress,
        );
      }
    } catch (_) {
      await logout();
    }
    return null;
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
  Future<void> logout() async {
    _currentUser = null;
    _apiClient.setAuthToken(null);
    await _privyManager.logout();
  }

  /// Soft-deletes user account in backend, deactivates agents, and deletes user from Privy Cloud.
  Future<void> deleteAccount() async {
    await _apiClient.delete('/auth/account');
    _currentUser = null;
    _apiClient.setAuthToken(null);
    await _privyManager.logout();
  }
}
