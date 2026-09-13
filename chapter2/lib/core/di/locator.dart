import 'package:agent_security/agent_security.dart';
import 'package:chapter2/core/config/app_config.dart';
import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/services/remote/services_api_service.dart';
import 'package:chapter2/features/shell/shell_tab_controller.dart';
import 'package:chapter2/features/world_id/remote/world_id_api_service.dart';
import 'package:chapter2/features/x402_approvals/remote/x402_approvals_api_service.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ble_client.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/websocket/chapter2_socket_service.dart';
import 'package:get_it/get_it.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
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

  if (!locator.isRegistered<X402ApprovalsApiService>()) {
    locator.registerLazySingleton<X402ApprovalsApiService>(
      () => X402ApprovalsApiService(apiClient: locator<ApiClient>()),
    );
  }

  if (!locator.isRegistered<WorldIdApiService>()) {
    locator.registerLazySingleton<WorldIdApiService>(
      () => WorldIdApiService(apiClient: locator<ApiClient>()),
    );
  }

  if (!locator.isRegistered<ServicesApiService>()) {
    locator.registerLazySingleton<ServicesApiService>(
      () => ServicesApiService(apiClient: locator<ApiClient>()),
    );
  }

  if (!locator.isRegistered<ShellTabController>()) {
    locator.registerLazySingleton<ShellTabController>(() => ShellTabController());
  }

  if (!locator.isRegistered<LedgerInterface>()) {
    locator.registerLazySingleton<LedgerInterface>(
      () => LedgerInterface.ble(onPermissionRequest: _requestLedgerBluetoothPermissions),
    );
  }

  if (!locator.isRegistered<LedgerBleClient>()) {
    locator.registerLazySingleton<LedgerBleClient>(
      () => LedgerInterfaceBleClient(locator<LedgerInterface>()),
    );
  }
}

Future<bool> _requestLedgerBluetoothPermissions(AvailabilityState status) async {
  if (await UniversalBle.hasPermissions()) {
    return true;
  }
  await UniversalBle.requestPermissions();
  return UniversalBle.hasPermissions();
}
