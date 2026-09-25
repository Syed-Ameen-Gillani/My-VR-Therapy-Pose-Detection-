import '../../core/errors/app_failure.dart';
import '../../features/patients/domain/patient.dart';
import '../../features/exercises/domain/exercise.dart';
import '../../features/sessions/domain/therapy_session.dart';
import '../../features/plans/domain/rehabilitation_plan.dart';

enum DemoScenario { populated, empty, error }

// Only the composition root imports fixtures; screens use domain contracts.
class DemoRepositories
    implements
        PatientRepository,
        ExerciseRepository,
        SessionRepository,
        PlanRepository {
  DemoRepositories({
    this.scenario = DemoScenario.populated,
    this.delay = const Duration(milliseconds: 180),
  });
  final DemoScenario scenario;
  final Duration delay;
  Future<List<T>> _respond<T>(List<T> values) async {
    await Future<void>.delayed(delay);
    if (scenario == DemoScenario.error) {
      throw const AppFailure(
        'The sample data could not be loaded. Please try again.',
      );
    }
    return List.unmodifiable(scenario == DemoScenario.empty ? <T>[] : values);
  }

  Future<T> _respondSingle<T>(T value) async {
    await Future<void>.delayed(delay);
    if (scenario == DemoScenario.error) {
      throw const AppFailure(
        'The sample data could not be loaded. Please try again.',
      );
    }
    return value;
  }

  late final List<Patient> _patients = [
    const Patient(
      id: 'p1',
      name: 'Ayesha Khan',
      initials: 'AK',
      goal: 'Build confidence with everyday shoulder movement',
    ),
    const Patient(
      id: 'p2',
      name: 'Omar Farooq',
      initials: 'OF',
      goal: 'Practice controlled knee movement',
    ),
    const Patient(
      id: 'p3',
      name: 'Maryam Ahmed',
      initials: 'MA',
      goal: 'Improve balance during seated exercises',
    ),
    const Patient(
      id: 'p4',
      name: 'Muhammad Abdullah Rahman',
      initials: 'MR',
      goal: 'Return to a consistent movement routine',
    ),
  ];

  @override
  Future<List<Patient>> getPatients() =>
      _respond(_patients.where((p) => !p.archived).toList());

  @override
  Future<Patient> createPatient({
    required String name,
    required String goal,
  }) async {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .take(2)
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
        .join();
    final patient = Patient(
      id: 'p${_patients.length + 1}',
      name: name.trim(),
      initials: initials.isEmpty ? 'PT' : initials,
      goal: goal.trim(),
    );
    _patients.add(patient);
    return patient;
  }

  @override
  Future<Patient> updatePatient({
    required String id,
    required String name,
    required String goal,
  }) async {
    await Future<void>.delayed(delay);
    if (scenario == DemoScenario.error) {
      throw const AppFailure(
        'The patient could not be saved. Please try again.',
      );
    }
    final index = _patients.indexWhere((p) => p.id == id);
    if (index == -1) {
      throw const AppFailure('Patient not found.');
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .take(2)
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
        .join();
    final updated = _patients[index].copyWith(
      name: name.trim(),
      goal: goal.trim(),
      initials: initials.isEmpty ? 'PT' : initials,
    );
    _patients[index] = updated;
    return updated;
  }

  @override
  Future<void> archivePatient(String id) async {
    final index = _patients.indexWhere((p) => p.id == id);
    if (index != -1) {
      final old = _patients[index];
      _patients[index] = Patient(
        id: old.id,
        name: old.name,
        goal: old.goal,
        initials: old.initials,
        archived: true,
        activePlanId: old.activePlanId,
      );
    }
  }

  @override
  Future<List<Exercise>> getExercises() => _respond(const [
    Exercise(
      id: 'e4',
      name: 'Arm hold',
      category: 'Upper body',
      instructions:
          'Hold the arm in the camera plane at the therapist-agreed target. Stop if uncomfortable.',
      equipment: 'Android phone on a stable stand',
    ),
    Exercise(
      id: 'e1',
      name: 'Shoulder reach',
      category: 'Upper body',
      instructions:
          'Sample exercise for interface demonstration. Follow the supervising therapist’s approved instructions when real plans are available.',
      equipment: 'VR headset and controllers',
    ),
    Exercise(
      id: 'e2',
      name: 'Seated knee extension',
      category: 'Lower body',
      instructions:
          'Sample exercise for interface demonstration. Movement limits and tracking support must be confirmed by the VR team.',
      equipment: 'Chair and agreed tracking system',
    ),
    Exercise(
      id: 'e3',
      name: 'Seated balance',
      category: 'Balance',
      instructions:
          'Sample exercise for interface demonstration. A therapist must confirm the appropriate exercise and equipment.',
      equipment: 'Chair and VR headset',
    ),
    Exercise(
      id: 'e5',
      name: 'Elbow flexion',
      category: 'Upper body',
      instructions: 'Bend and slowly straighten the selected elbow in view.',
      equipment: 'Android phone on a stable stand',
    ),
    Exercise(
      id: 'e6',
      name: 'Seated hip flexion',
      category: 'Lower body',
      instructions: 'Lift the selected knee gently while seated, then lower it.',
      equipment: 'Chair and Android phone',
    ),
    Exercise(
      id: 'e7',
      name: 'Seated knee flexion',
      category: 'Lower body',
      instructions: 'Bend and extend the selected knee within the agreed range.',
      equipment: 'Chair and Android phone',
    ),
    Exercise(
      id: 'e8',
      name: 'Shoulder abduction',
      category: 'Upper body',
      instructions: 'Raise the selected arm out to the side and return slowly.',
      equipment: 'Android phone on a stable stand',
    ),
    Exercise(
      id: 'e9',
      name: 'Trunk alignment hold',
      category: 'Posture',
      instructions: 'Sit tall and hold your trunk centered with steady shoulders.',
      equipment: 'Chair and Android phone',
    ),
    Exercise(
      id: 'e10',
      name: 'Sit to stand',
      category: 'Functional movement',
      instructions: 'Stand from the chair with control, then sit down slowly.',
      equipment: 'Stable chair and Android phone',
    ),
  ]);
  late final List<RehabilitationPlan> _plans = [
    const RehabilitationPlan(
      id: 'plan_p1',
      patientId: 'p1',
      title: 'Shoulder mobility',
      exerciseIds: ['e1', 'e3'],
      scheduledSessions: 4,
      version: 1,
    ),
    const RehabilitationPlan(
      id: 'plan_p2',
      patientId: 'p2',
      title: 'Controlled movement',
      exerciseIds: ['e2'],
      scheduledSessions: 3,
      version: 1,
    ),
  ];

  @override
  Future<List<RehabilitationPlan>> getPlans() =>
      _respond(_plans.where((p) => p.status == 'active').toList());

  @override
  Future<RehabilitationPlan?> getPlanForPatient(String patientId) =>
      _respondSingle(
        _plans
            .where((p) => p.patientId == patientId && p.status == 'active')
            .firstOrNull,
      );

  @override
  Future<RehabilitationPlan> savePlan({
    required String patientId,
    required String title,
    required List<String> exerciseIds,
    required int scheduledSessions,
  }) async {
    final existingIndex = _plans.indexWhere(
      (p) => p.patientId == patientId && p.status == 'active',
    );
    final version = existingIndex != -1 ? _plans[existingIndex].version + 1 : 1;
    final planId = existingIndex != -1
        ? (_plans[existingIndex].id ?? 'plan_$patientId')
        : 'plan_${patientId}_$version';

    final newPlan = RehabilitationPlan(
      id: planId,
      patientId: patientId,
      title: title,
      exerciseIds: exerciseIds,
      scheduledSessions: scheduledSessions,
      version: version,
      status: 'active',
    );

    if (existingIndex != -1) {
      _plans[existingIndex] = newPlan;
    } else {
      _plans.add(newPlan);
    }

    final pIndex = _patients.indexWhere((p) => p.id == patientId);
    if (pIndex != -1) {
      final old = _patients[pIndex];
      _patients[pIndex] = Patient(
        id: old.id,
        name: old.name,
        goal: old.goal,
        initials: old.initials,
        archived: old.archived,
        activePlanId: planId,
      );
    }

    return newPlan;
  }

  @override
  Future<List<TherapySession>> getSessions() => _respond(_sessions);

  @override
  Future<void> createSession(
    TherapySession session, {
    required Map<String, Object?> payload,
    required String planId,
    required int planVersion,
  }) async {
    await _respond([session]);
    if (!_sessions.any((s) => s.id == session.id)) _sessions.add(session);
  }

  late final List<TherapySession> _sessions = [
    TherapySession(
      id: 's1',
      patientId: 'p1',
      exerciseId: 'e1',
      startedAt: DateTime.utc(2026, 9, 24, 9),
      durationMinutes: 12,
      repetitions: 10,
      analysis: AnalysisStatus.ready,
      rangeDegrees: 72,
      aiFeedback:
          'Movement stayed controlled. Continue the current shoulder reach plan.',
      trackingQuality: 'High',
      modelVersion: 'demo-pose-v1',
    ),
    TherapySession(
      id: 's2',
      patientId: 'p2',
      exerciseId: 'e2',
      startedAt: DateTime.utc(2026, 9, 24, 8),
      durationMinutes: 8,
      repetitions: 8,
      analysis: AnalysisStatus.pending,
      aiFeedback: 'Analysis is waiting for the AI result.',
      trackingQuality: 'Pending',
    ),
    TherapySession(
      id: 's3',
      patientId: 'p1',
      exerciseId: 'e1',
      startedAt: DateTime.utc(2026, 9, 22, 9),
      durationMinutes: 10,
      repetitions: 8,
      analysis: AnalysisStatus.ready,
      rangeDegrees: 65,
      aiFeedback: 'Range improved compared with the previous measured session.',
      trackingQuality: 'Medium',
      modelVersion: 'demo-pose-v1',
      reviewed: true,
    ),
    TherapySession(
      id: 's4',
      patientId: 'p3',
      exerciseId: 'e3',
      startedAt: DateTime.utc(2026, 9, 21, 10),
      durationMinutes: 6,
      repetitions: 5,
      analysis: AnalysisStatus.incomplete,
      aiFeedback:
          'Tracking was incomplete, so no movement conclusion is shown.',
      trackingQuality: 'Low',
    ),
    TherapySession(
      id: 's5',
      patientId: 'p1',
      exerciseId: 'e1',
      startedAt: DateTime.utc(2026, 9, 20, 9),
      durationMinutes: 9,
      repetitions: 7,
      analysis: AnalysisStatus.ready,
      rangeDegrees: 58,
      aiFeedback: 'Baseline sample captured for future comparison.',
      trackingQuality: 'Medium',
      modelVersion: 'demo-pose-v1',
      reviewed: true,
    ),
  ];

  @override
  Future<void> saveReview({
    required String sessionId,
    required String note,
  }) async {
    await Future<void>.delayed(delay);
    if (scenario == DemoScenario.error) {
      throw const AppFailure(
        'The review could not be saved. Please try again.',
      );
    }
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) {
      throw const AppFailure('Session not found.');
    }
    _sessions[index] = _sessions[index].copyWith(reviewed: true);
  }
}
