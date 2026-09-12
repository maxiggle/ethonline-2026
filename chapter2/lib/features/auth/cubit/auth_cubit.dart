import 'package:bloc/bloc.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthService authService})
    : _authService = authService,
      super(const AuthState());

  final AuthService _authService;

  Future<void> loginWithPrivyToken(String token) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authService.loginWithPrivy(token);
      final agents = await _authService.getAgents();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          agents: agents,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  Future<void> loginWithGoogle() async {
    await loginWithPrivyToken('test_token_google_user');
  }

  Future<void> refreshAgents() async {
    if (!state.isAuthenticated) return;
    try {
      final agents = await _authService.getAgents();
      emit(state.copyWith(agents: agents));
    } catch (_) {}
  }

  void logout() {
    _authService.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
