enum AnalysisStatus { ready, pending, incomplete, failed }

class TherapySession {
  const TherapySession({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.startedAt,
    required this.durationMinutes,
    required this.repetitions,
    required this.analysis,
    this.rangeDegrees,
    this.aiFeedback,
    this.trackingQuality,
    this.modelVersion,
    this.reviewed = false,
  });
  final String id, patientId, exerciseId;
  final DateTime startedAt;
  final int durationMinutes, repetitions;
  final AnalysisStatus analysis;
  final double? rangeDegrees;
  final String? aiFeedback, trackingQuality, modelVersion;
  final bool reviewed;

  TherapySession copyWith({
    String? id,
    String? patientId,
    String? exerciseId,
    DateTime? startedAt,
    int? durationMinutes,
    int? repetitions,
    AnalysisStatus? analysis,
    double? rangeDegrees,
    String? aiFeedback,
    String? trackingQuality,
    String? modelVersion,
    bool? reviewed,
  }) => TherapySession(
    id: id ?? this.id,
    patientId: patientId ?? this.patientId,
    exerciseId: exerciseId ?? this.exerciseId,
    startedAt: startedAt ?? this.startedAt,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    repetitions: repetitions ?? this.repetitions,
    analysis: analysis ?? this.analysis,
    rangeDegrees: rangeDegrees ?? this.rangeDegrees,
    aiFeedback: aiFeedback ?? this.aiFeedback,
    trackingQuality: trackingQuality ?? this.trackingQuality,
    modelVersion: modelVersion ?? this.modelVersion,
    reviewed: reviewed ?? this.reviewed,
  );
}

abstract interface class SessionRepository {
  Future<List<TherapySession>> getSessions();
  Future<void> saveReview({required String sessionId, required String note});
}
