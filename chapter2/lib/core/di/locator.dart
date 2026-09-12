import 'package:agent_security/agent_security.dart';
import 'package:chapter2/core/config/app_config.dart';
import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/websocket/chapter2_socket_service.dart';
import 'package:get_it/get_it.dart';
import 'package:ledger_keyring/ledger_keyring.dart';

final GetIt locator = GetIt.instance;

void setupServiceLocator({String? backendBaseUrl}) {
  final resolvedBaseUrl = backendBaseUrl ?? AppConfig.backendBaseUrl;

  if (!locator.isRegistered<ApiClient>()) {
    locator.registerLazySingleton<ApiClient>(
      () => ApiClient(baseUrl: resolvedBaseUrl),
    );
  }

  if (!locator.isRegistered<AuthService>()) {
    locator.registerLazySingleton<AuthService>(
      () => AuthService(apiClient: locator<ApiClient>()),
    );
  }

  if (!locator.isRegistered<Chapter2ApiService>()) {
    locator.registerLazySingleton<Chapter2ApiService>(
      () => Chapter2ApiService(apiClient: locator<ApiClient>()),
    );
  }

  if (!locator.isRegistered<Chapter2SocketService>()) {
    locator.registerLazySingleton<Chapter2SocketService>(
      () => Chapter2SocketService(gatewayUrl: AppConfig.websocketUrl),
    );
  }

  if (!locator.isRegistered<LedgerKeyring>()) {
    locator.registerLazySingleton<LedgerKeyring>(
      () => LedgerKeyring(),
    );
  }

  if (!locator.isRegistered<AgentSecurity>()) {
    locator.registerLazySingleton<AgentSecurity>(
      () => AgentSecurity(),
    );
  }
}
