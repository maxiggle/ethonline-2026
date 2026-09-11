import 'package:equatable/equatable.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.agents = const [],
    this.errorMessage,
  });

  final AuthStatus status;
  final UserIdentity? user;
  final List<AgentModel> agents;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserIdentity? user,
    List<AgentModel>? agents,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      agents: agents ?? this.agents,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, agents, errorMessage];
}
