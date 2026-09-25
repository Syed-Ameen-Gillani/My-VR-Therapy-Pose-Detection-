import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../../sessions/domain/therapy_session.dart';

final progressSamplesProvider = FutureProvider.autoDispose
    .family<List<TherapySession>, String>((ref, id) async {
      final sessions = await ref.watch(patientSessionsProvider(id).future);
      return comparableShoulderSamples(sessions);
    });

List<TherapySession> comparableExerciseSamples(
  List<TherapySession> sessions,
  String exerciseId,
) {
  final eligible = sessions
      .where((s) {
        if (s.exerciseId != exerciseId ||
            (s.analysis != AnalysisStatus.ready &&
                s.trackingQuality != 'High')) {
          return false;
        }
        return switch (exerciseId) {
          'e1' || 'e2' => s.rangeDegrees != null &&
              s.rangeDegrees!.isFinite &&
              s.rangeDegrees! >= 0 &&
              s.rangeDegrees! <= 180,
          'e3' => s.analysisPayload['stability_percent'] is num,
          'e4' => s.analysisPayload['hold_seconds'] is num,
          _ => false,
        };
      })
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  if (eligible.isEmpty) return eligible;

  // Keep the newest compatible series instead of letting one side/model switch
  // make all earlier measurements disappear.
  final series = <String, List<TherapySession>>{};
  for (final sample in eligible) {
    final key = [
      sample.analysisPayload['source'] ?? 'legacy',
      sample.analysisPayload['side'] ?? 'unspecified',
      sample.analysisPayload['rule_version'] ?? 'legacy',
      sample.modelVersion ?? 'legacy',
    ].join('|');
    (series[key] ??= []).add(sample);
  }
  return series.values.reduce(
    (a, b) => a.last.startedAt.isAfter(b.last.startedAt) ? a : b,
  );
}

/// Compare only the newest measurement series, never opposite sides or models.
List<TherapySession> comparableShoulderSamples(List<TherapySession> sessions) {
  return comparableExerciseSamples(sessions, 'e1');
}

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, required this.patientId});
  final String patientId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Patient progress')),
    body: PageBody(
      children: [
        const PageHeading(
          'Small steps, clearly seen',
          'Compatible movement measurements by exercise',
        ),
        // const StatusBadge('Movement estimates'),
        const SizedBox(height: 24),
        AsyncContent(
          value: ref.watch(patientSessionsProvider(patientId)),
          onRetry: () => ref.invalidate(sessionsProvider),
          builder: (sessions) {
            final shoulder = comparableExerciseSamples(sessions, 'e1');
            final knee = comparableExerciseSamples(sessions, 'e2');
            final balance = comparableExerciseSamples(sessions, 'e3');
            final hold = comparableExerciseSamples(sessions, 'e4');
            final series = [shoulder, knee, balance, hold];
            if (series.every((samples) => samples.isEmpty)) {
              return const StateMessage(
                title: 'No comparable measurements',
                message:
                    'Complete a camera exercise with visible joints and good tracking. Valid measurements will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in [
                  ('Shoulder range', shoulder, 'degrees', 180.0),
                  ('Knee range', knee, 'degrees', 180.0),
                  ('Balance stability', balance, '% stable', 100.0),
                  ('Arm hold', hold, 'seconds', 30.0),
                ])
                  if (entry.$2.isNotEmpty)
                    _ProgressMetricCard(
                      title: entry.$1,
                      samples: entry.$2,
                      unit: entry.$3,
                      scale: entry.$4,
                    ),
                const SizedBox(height: 16),
                const Text(
                  'Measurements are motion estimates for therapist review, not clinical conclusions.',
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ProgressMetricCard extends StatelessWidget {
  const _ProgressMetricCard({
    required this.title,
    required this.samples,
    required this.unit,
    required this.scale,
  });

  final String title, unit;
  final List<TherapySession> samples;
  final double scale;

  double _value(TherapySession session) {
    if (session.rangeDegrees != null) return session.rangeDegrees!;
    final key = title == 'Balance stability'
        ? 'stability_percent'
        : 'hold_seconds';
    return (session.analysisPayload[key] as num).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Each bar is one measured session · scale 0–${scale.round()}'),
          const SizedBox(height: 16),
          for (final sample in samples)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                label:
                    '${DateFormat('d MMM').format(sample.startedAt)}, ${_value(sample).round()} $unit',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('d MMM').format(sample.startedAt)} · ${_value(sample).round()} $unit',
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (_value(sample) / scale).clamp(0, 1),
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
