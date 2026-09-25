class RehabilitationPlan {
  const RehabilitationPlan({
    this.id,
    required this.patientId,
    required this.title,
    required this.exerciseIds,
    required this.scheduledSessions,
    this.version = 1,
    this.status = 'active',
  });
  final String? id;
  final String patientId, title;
  final List<String> exerciseIds;
  final int scheduledSessions, version;
  final String status;
}

abstract interface class PlanRepository {
  Future<List<RehabilitationPlan>> getPlans();
  Future<RehabilitationPlan?> getPlanForPatient(String patientId);
  Future<RehabilitationPlan> savePlan({
    required String patientId,
    required String title,
    required List<String> exerciseIds,
    required int scheduledSessions,
  });
}
