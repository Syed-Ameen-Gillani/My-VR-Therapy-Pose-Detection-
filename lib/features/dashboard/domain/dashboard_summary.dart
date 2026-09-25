import '../../patients/domain/patient.dart';
import '../../plans/domain/rehabilitation_plan.dart';
import '../../sessions/domain/therapy_session.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.patientCount,
    required this.reviewCount,
    required this.completedScheduledSessions,
    required this.scheduledSessions,
    required this.recentSessions,
  });

  final int patientCount;
  final int reviewCount;
  final int completedScheduledSessions;
  final int scheduledSessions;
  final List<TherapySession> recentSessions;

  int? get adherencePercent {
    if (scheduledSessions == 0) return null;
    return ((completedScheduledSessions / scheduledSessions) * 100).round();
  }

  String get adherenceValue =>
      adherencePercent == null ? 'N/A' : '$adherencePercent%';

  String get adherenceDetail {
    if (scheduledSessions == 0) return 'No scheduled sessions yet';
    return '$completedScheduledSessions of $scheduledSessions scheduled sessions';
  }
}

DashboardSummary buildDashboardSummary({
  required List<Patient> patients,
  required List<TherapySession> sessions,
  required List<RehabilitationPlan> plans,
}) {
  final activePlans = plans.where((plan) => plan.status == 'active').toList();
  final plannedPatientIds = activePlans.map((plan) => plan.patientId).toSet();
  final scheduledSessions = activePlans.fold<int>(
    0,
    (total, plan) => total + plan.scheduledSessions,
  );
  final completedEligibleSessions = sessions
      .where(
        (session) =>
            session.analysis == AnalysisStatus.ready &&
            plannedPatientIds.contains(session.patientId),
      )
      .map((session) => session.id)
      .toSet()
      .length;
  final completedScheduledSessions = scheduledSessions == 0
      ? 0
      : completedEligibleSessions.clamp(0, scheduledSessions);
  final reviewCount = sessions
      .where(
        (session) =>
            session.analysis == AnalysisStatus.ready && !session.reviewed,
      )
      .length;
  final recentSessions = [...sessions]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  return DashboardSummary(
    patientCount: patients.length,
    reviewCount: reviewCount,
    completedScheduledSessions: completedScheduledSessions,
    scheduledSessions: scheduledSessions,
    recentSessions: List.unmodifiable(recentSessions.take(3)),
  );
}
