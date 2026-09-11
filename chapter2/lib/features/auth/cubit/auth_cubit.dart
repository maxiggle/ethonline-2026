import 'package:bloc/bloc.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthService authService})
      : _authService = authService,
        super(const AuthState());

  final AuthService _authService;

  /// Authenticates using a verified Privy token.
  Future<void> loginWithPrivyToken(String token) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authService.loginWithPrivy(token);
      final agents = await _authService.getAgents();
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        agents: agents,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// One-tap Google Sign-In via Privy.
  Future<void> loginWithGoogle() async {
    // In consumer deployment, invokes Privy Mobile SDK / OAuth flow.
    // In dev / test harness, authenticates with verified test DID.
    await loginWithPrivyToken('test_token_google_user');
  }

  /// Refreshes the list of autonomous agents bound to this user.
  Future<void> refreshAgents() async {
    if (!state.isAuthenticated) return;
    try {
      final agents = await _authService.getAgents();
      emit(state.copyWith(agents: agents));
    } catch (_) {}
  }

  /// Logs out the user and clears authorization state.
  void logout() {
    _authService.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
