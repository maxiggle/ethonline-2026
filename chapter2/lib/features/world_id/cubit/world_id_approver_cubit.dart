import 'dart:async';

import 'package:chapter2/features/world_id/cubit/world_id_approver_state.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';
import 'package:chapter2/features/world_id/remote/world_id_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorldIdApproverCubit extends Cubit<WorldIdApproverState> {
  WorldIdApproverCubit({
    required WorldIdApiService apiService,
    Duration pollInterval = const Duration(seconds: 2),
  })  : _apiService = apiService,
        _pollInterval = pollInterval,
        super(const WorldIdApproverState());

  final WorldIdApiService _apiService;
  final Duration _pollInterval;
  Timer? _pollingTimer;

  Future<void> loadStatus() async {
    emit(state.copyWith(status: WorldIdApproverCubitStatus.loading, clearErrorMessage: true));
    try {
      final status = await _apiService.fetchApproverStatus();
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.ready,
        approverStatus: status,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.failure,
        errorMessage: _describeError(error),
      ));
    }
  }

  Future<void> startOrbVerification() async {
    _stopPolling();
    emit(state.copyWith(status: WorldIdApproverCubitStatus.verifying, clearErrorMessage: true));
    try {
      final verification = await _apiService.startOrbVerification();
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.verifying,
        verification: verification,
      ));

      _startPolling(verification.requestId);
    } catch (error) {
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.failure,
        errorMessage: _describeError(error),
      ));
    }
  }

  void _startPolling(String requestId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _pollOnce(requestId));
  }

  Future<void> _pollOnce(String requestId) async {
    try {
      final updated = await _apiService.fetchOrbVerification(requestId);
      emit(state.copyWith(verification: updated));

      if (updated.status == WorldIdOrbVerificationStatus.verified ||
          updated.status == WorldIdOrbVerificationStatus.bound ||
          updated.status == WorldIdOrbVerificationStatus.failed ||
          updated.status == WorldIdOrbVerificationStatus.expired) {
        _stopPolling();
        if (updated.status == WorldIdOrbVerificationStatus.failed && updated.errorMessage != null) {
          emit(state.copyWith(errorMessage: updated.errorMessage));
        }
      }
    } catch (error) {
      _stopPolling();
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.failure,
        errorMessage: _describeError(error),
      ));
    }
  }

  Future<void> bindWithLedger(
    Future<String> Function(String message) signPersonalMessageOnLedger,
  ) async {
    final verification = state.verification;
    if (verification == null ||
        verification.status != WorldIdOrbVerificationStatus.verified ||
        verification.bindMessage == null) {
      return;
    }

    emit(state.copyWith(status: WorldIdApproverCubitStatus.binding, clearErrorMessage: true));
    try {
      final signature = await signPersonalMessageOnLedger(verification.bindMessage!);
      final approverStatus = await _apiService.bindLedgerApprover(
        requestId: verification.requestId,
        signature: signature,
      );
      _stopPolling();
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.ready,
        approverStatus: approverStatus,
        clearVerification: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: WorldIdApproverCubitStatus.failure,
        errorMessage: _describeError(error),
      ));
    }
  }

  void cancelVerification() {
    _stopPolling();
    emit(state.copyWith(
      status: WorldIdApproverCubitStatus.ready,
      clearVerification: true,
      clearErrorMessage: true,
    ));
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  String _describeError(Object error) => error.toString();

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
