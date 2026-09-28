import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/features/progress/presentation/progress_screen.dart';
import 'package:fyp_abdullah/features/sessions/domain/therapy_session.dart';

TherapySession sample(
  int day, {
  String side = 'right',
  String source = 'android_camera',
  String rule = 'v1',
}) => TherapySession(
  id: '$day',
  patientId: 'p1',
  exerciseId: 'e1',
  startedAt: DateTime.utc(2026, 9, day),
  durationMinutes: 1,
  repetitions: 1,
  analysis: AnalysisStatus.ready,
  rangeDegrees: 80,
  modelVersion: 'mlkit',
  analysisPayload: {'source': source, 'side': side, 'rule_version': rule},
);

void main() {
  test('trunk holds and sit-to-stand measurements are included', () {
    for (final id in ['e9', 'e10']) {
      final session = TherapySession(
        id: id,
        patientId: 'p1',
        exerciseId: id,
        startedAt: DateTime.utc(2026, 9, 1),
        durationMinutes: 1,
        repetitions: 1,
        analysis: AnalysisStatus.ready,
        rangeDegrees: id == 'e10' ? 175 : null,
        analysisPayload: const {'hold_seconds': 3.0},
      );
      expect(comparableExerciseSamples([session], id), [session]);
    }
  });

  test('nonfinite and negative holds are excluded', () {
    for (final value in [double.nan, double.infinity, -1.0]) {
      final session = TherapySession(
        id: 'invalid',
        patientId: 'p1',
        exerciseId: 'e9',
        startedAt: DateTime.utc(2026, 9, 1),
        durationMinutes: 1,
        repetitions: 0,
        analysis: AnalysisStatus.ready,
        analysisPayload: {'hold_seconds': value},
      );
      expect(comparableExerciseSamples([session], 'e9'), isEmpty);
    }
  });
  test(
    'progress excludes opposite side, other source and other rule versions',
    () {
      final result = comparableShoulderSamples([
        sample(1),
        sample(2, side: 'left'),
        sample(3, source: 'demo'),
        sample(4, rule: 'v2'),
        sample(5),
      ]);
      expect(result.map((s) => s.id), ['1', '5']);
    },
  );

  test('progress includes high-quality short camera samples', () {
    final shortHighQuality = TherapySession(
      id: 'short',
      patientId: 'p1',
      exerciseId: 'e1',
      startedAt: DateTime.utc(2026, 9, 6),
      durationMinutes: 0,
      repetitions: 1,
      analysis: AnalysisStatus.incomplete,
      rangeDegrees: 82,
      trackingQuality: 'High',
      modelVersion: 'mlkit',
      analysisPayload: const {
        'source': 'android_camera',
        'side': 'right',
        'rule_version': 'v1',
      },
    );
    expect(comparableShoulderSamples([shortHighQuality]).map((s) => s.id), [
      'short',
    ]);
  });
}
