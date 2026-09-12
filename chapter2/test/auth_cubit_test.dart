import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';
import 'package:chapter2/core/config/app_config.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/core/network/api_client.dart';

class MockAuthService extends AuthService {
  MockAuthService() : super(apiClient: ApiClient(baseUrl: AppConfig.backendBaseUrl));

  bool shouldThrow = false;

  final mockUser = const UserIdentity(
    id: 'user_123',
    email: 'user@gmail.com',
    name: 'Test User',
    walletAddress: '0x1111111111111111111111111111111111111111',
  );

  final List<AgentModel> mockAgents = [
    const AgentModel(
      id: 'agent_1',
      userId: 'user_123',
      agentAddress: '0x2222222222222222222222222222222222222222',
      name: 'Alpha Treasury Agent',
      purpose: 'Autonomous Yield Ops',
      safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
      status: 'ACTIVE',
      chainId: 84532,
    ),
  ];

  @override
  Future<UserIdentity> loginWithGoogle() async {
    if (shouldThrow) throw Exception('Privy token verification failed');
    return mockUser;
  }

  @override
  Future<UserIdentity> loginWithPrivy(String authToken, {String? email, String? name, String? walletAddress}) async {
    if (shouldThrow) throw Exception('Privy token verification failed');
    return mockUser;
  }

  @override
  Future<List<AgentModel>> getAgents() async {
    if (shouldThrow) throw Exception('Failed to fetch agents');
    return mockAgents;
  }

  @override
  Future<UserIdentity?> checkSession() async {
    if (shouldThrow) throw Exception('Session check error');
    return mockUser;
  }

  @override
  Future<void> logout() async {}
}

void main() {
  group('AuthCubit Tests', () {
    test('initial state is unauthenticated with empty agents', () {
      final mockService = MockAuthService();
      final cubit = AuthCubit(authService: mockService);

      expect(cubit.state.status, AuthStatus.initial);
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.user, isNull);
      expect(cubit.state.agents, isEmpty);
    });

    test('loginWithGoogle emits loading and then authenticated with user and agents', () async {
      final mockService = MockAuthService();
      final cubit = AuthCubit(authService: mockService);

      await cubit.loginWithGoogle();

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.user?.email, 'user@gmail.com');
      expect(cubit.state.user?.walletAddress, '0x1111111111111111111111111111111111111111');
      expect(cubit.state.agents.length, 1);
      expect(cubit.state.agents.first.name, 'Alpha Treasury Agent');
    });

    test('login error emits error state with descriptive message', () async {
      final mockService = MockAuthService()..shouldThrow = true;
      final cubit = AuthCubit(authService: mockService);

      await cubit.loginWithGoogle();

      expect(cubit.state.status, AuthStatus.error);
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.errorMessage, contains('Privy token verification failed'));
    });

    test('logout resets state to unauthenticated', () async {
      final mockService = MockAuthService();
      final cubit = AuthCubit(authService: mockService);

      await cubit.loginWithGoogle();
      expect(cubit.state.isAuthenticated, isTrue);

      await cubit.logout();
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.user, isNull);
    });

    test('checkSession with valid session restores authenticated user and agents', () async {
      final mockService = MockAuthService();
      final cubit = AuthCubit(authService: mockService);

      await cubit.checkSession();

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.user?.email, 'user@gmail.com');
      expect(cubit.state.agents.length, 1);
    });
  });
}
