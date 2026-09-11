import 'package:chapter2/features/dashboard/models/treasury_metrics.dart';
import 'package:equatable/equatable.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.metrics,
    this.errorMessage,
  });

  final DashboardStatus status;
  final TreasuryMetrics? metrics;
  final String? errorMessage;

  DashboardState copyWith({
    DashboardStatus? status,
    TreasuryMetrics? metrics,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, metrics, errorMessage];
}
