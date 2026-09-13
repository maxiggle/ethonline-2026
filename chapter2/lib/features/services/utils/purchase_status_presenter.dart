import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:chapter2/shared/theme/app_colors.dart';
import 'package:flutter/widgets.dart' show Color;

/// How far a step in the standard happy path (Queued → Processing →
/// Authorized → Paid) has gotten for a given [PurchaseRequest].
enum PurchaseTimelineStepState { done, current, pending, error }

class PurchaseTimelineStep {
  const PurchaseTimelineStep({required this.label, required this.state});

  final String label;
  final PurchaseTimelineStepState state;
}

/// The visual tone of a status: matches the Guardian verdict palette
/// (allow/escalate/block) plus a neutral tone for in-flight states.
enum PurchaseStatusTone { neutral, allow, escalate, block }

/// What the purchase detail screen shows for a [PurchaseRequest], derived
/// only from fields the backend actually returned — never invented.
class PurchaseStatusView {
  const PurchaseStatusView({
    required this.steps,
    required this.headline,
    required this.tone,
    this.hint,
    this.reasons = const [],
    this.showApprovalsCta = false,
  });

  final List<PurchaseTimelineStep> steps;
  final String headline;
  final PurchaseStatusTone tone;
  final String? hint;
  final List<String> reasons;
  final bool showApprovalsCta;
}

/// Maps a [PurchaseRequest] to what TICKET-MOBILE-003's status table asks
/// the purchase detail screen to show.
class PurchaseStatusPresenter {
  const PurchaseStatusPresenter._();

  static const _stepLabels = ['Queued', 'Processing', 'Authorized', 'Paid'];
  static const _workerHint = 'Is the agent worker running? npm --prefix scripts run agent:worker';
  static const _workerHintDelay = Duration(seconds: 30);

  static PurchaseStatusView describe(PurchaseRequest request, {DateTime? now}) {
    final steps = _stepsFor(request.status, request.decision);

    switch (request.status) {
      case PurchaseRequestStatus.queued:
        final elapsed = (now ?? DateTime.now().toUtc()).difference(request.createdAt);
        return PurchaseStatusView(
          steps: steps,
          headline: 'Waiting for your agent to pick this up.',
          hint: elapsed >= _workerHintDelay ? _workerHint : null,
          tone: PurchaseStatusTone.neutral,
        );
      case PurchaseRequestStatus.processing:
        return PurchaseStatusView(
          steps: steps,
          headline: 'Agent is requesting payment terms…',
          tone: PurchaseStatusTone.neutral,
        );
      case PurchaseRequestStatus.authorized:
        if (request.decision == GuardianVerdict.escalate) {
          return PurchaseStatusView(
            steps: steps,
            headline: 'Needs your Ledger approval',
            reasons: request.reasons,
            tone: PurchaseStatusTone.escalate,
            showApprovalsCta: true,
          );
        }
        return PurchaseStatusView(
          steps: steps,
          headline: 'Guardian allowed it. The agent is paying…',
          tone: PurchaseStatusTone.allow,
        );
      case PurchaseRequestStatus.paid:
        return PurchaseStatusView(steps: steps, headline: 'Paid', tone: PurchaseStatusTone.allow);
      case PurchaseRequestStatus.blocked:
        return PurchaseStatusView(
          steps: steps,
          headline: 'Blocked by the Guardian',
          reasons: request.reasons,
          tone: PurchaseStatusTone.block,
        );
      case PurchaseRequestStatus.rejected:
      case PurchaseRequestStatus.expired:
      case PurchaseRequestStatus.failed:
        final error = request.error;
        return PurchaseStatusView(
          steps: steps,
          headline: (error != null && error.isNotEmpty) ? error : '${request.status.label} — no further details were provided.',
          tone: PurchaseStatusTone.block,
        );
    }
  }

  /// Builds the four-step happy-path timeline. Terminal failures place the
  /// error at Authorized when no Guardian [decision] was ever recorded (the
  /// request never got that far), or at Paid when a decision was recorded
  /// but the payment itself did not complete — inferred from data the
  /// backend actually returned, not guessed.
  static List<PurchaseTimelineStep> _stepsFor(PurchaseRequestStatus status, GuardianVerdict? decision) {
    late final List<PurchaseTimelineStepState> states;
    switch (status) {
      case PurchaseRequestStatus.queued:
        states = const [
          PurchaseTimelineStepState.current,
          PurchaseTimelineStepState.pending,
          PurchaseTimelineStepState.pending,
          PurchaseTimelineStepState.pending,
        ];
      case PurchaseRequestStatus.processing:
        states = const [
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.current,
          PurchaseTimelineStepState.pending,
          PurchaseTimelineStepState.pending,
        ];
      case PurchaseRequestStatus.authorized:
        states = const [
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.current,
          PurchaseTimelineStepState.pending,
        ];
      case PurchaseRequestStatus.paid:
        states = const [
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.done,
        ];
      case PurchaseRequestStatus.blocked:
        states = const [
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.done,
          PurchaseTimelineStepState.error,
          PurchaseTimelineStepState.pending,
        ];
      case PurchaseRequestStatus.rejected:
      case PurchaseRequestStatus.expired:
      case PurchaseRequestStatus.failed:
        states = decision != null
            ? const [
                PurchaseTimelineStepState.done,
                PurchaseTimelineStepState.done,
                PurchaseTimelineStepState.done,
                PurchaseTimelineStepState.error,
              ]
            : const [
                PurchaseTimelineStepState.done,
                PurchaseTimelineStepState.done,
                PurchaseTimelineStepState.error,
                PurchaseTimelineStepState.pending,
              ];
    }
    return [
      for (var i = 0; i < _stepLabels.length; i++) PurchaseTimelineStep(label: _stepLabels[i], state: states[i]),
    ];
  }
}

/// The status pill shown on a purchase row and the detail screen: colored
/// with the same ALLOW/ESCALATE/BLOCK palette as the rest of the app.
class PurchaseStatusChip {
  const PurchaseStatusChip({
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color border;
  final Color textColor;

  static PurchaseStatusChip forRequest(PurchaseRequest request) {
    switch (request.status) {
      case PurchaseRequestStatus.queued:
      case PurchaseRequestStatus.processing:
        return PurchaseStatusChip(
          label: request.status.label,
          background: AppColors.surfaceRaised,
          border: AppColors.border,
          textColor: AppColors.textSecondary,
        );
      case PurchaseRequestStatus.authorized:
        if (request.decision == GuardianVerdict.escalate) {
          return PurchaseStatusChip(
            label: 'ESCALATED',
            background: AppColors.escalateBackground,
            border: AppColors.escalateBorder,
            textColor: AppColors.escalateText,
          );
        }
        return PurchaseStatusChip(
          label: 'AUTHORIZED',
          background: AppColors.allowBackground,
          border: AppColors.allowBorder,
          textColor: AppColors.allowText,
        );
      case PurchaseRequestStatus.paid:
        return PurchaseStatusChip(
          label: 'PAID',
          background: AppColors.allowBackground,
          border: AppColors.allowBorder,
          textColor: AppColors.allowText,
        );
      case PurchaseRequestStatus.blocked:
      case PurchaseRequestStatus.rejected:
      case PurchaseRequestStatus.expired:
      case PurchaseRequestStatus.failed:
        return PurchaseStatusChip(
          label: request.status.label,
          background: AppColors.blockBackground,
          border: AppColors.blockBorder,
          textColor: AppColors.blockText,
        );
    }
  }
}
