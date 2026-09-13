import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:equatable/equatable.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.recentActions = const [],
    this.errorMessage,
  });

  final DashboardStatus status;
  final List<TreasuryAction> recentActions;
  final String? errorMessage;

  DashboardState copyWith({
    DashboardStatus? status,
    List<TreasuryAction>? recentActions,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      recentActions: recentActions ?? this.recentActions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, recentActions, errorMessage];
}
