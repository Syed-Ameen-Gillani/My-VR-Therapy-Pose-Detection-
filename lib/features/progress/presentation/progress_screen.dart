import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../../sessions/domain/therapy_session.dart';

final progressSamplesProvider = FutureProvider.autoDispose
    .family<List<TherapySession>, String>((ref, id) async {
      final sessions = await ref.watch(patientSessionsProvider(id).future);
      // One compatible sample exercise and unit, sorted once per input update.
      return sessions
          .where(
            (s) =>
                s.exerciseId == 'e1' &&
                s.analysis == AnalysisStatus.ready &&
                s.rangeDegrees != null,
          )
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    });

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
          'Shoulder reach · September 2026 sample data',
        ),
        const StatusBadge('Sample movement measurements'),
        const SizedBox(height: 24),
        AsyncContent(
          value: ref.watch(progressSamplesProvider(patientId)),
          onRetry: () => ref.invalidate(sessionsProvider),
          builder: (samples) {
            if (samples.isEmpty) {
              return const StateMessage(
                title: 'No comparable measurements',
                message:
                    'Progress appears when compatible, valid measurements are available. Missing results are not zero.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shoulder range',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('Degrees · Each bar is one measured session'),
                      const SizedBox(height: 20),
                      for (final s in samples)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Semantics(
                            label:
                                '${DateFormat('d MMM').format(s.startedAt)}, ${s.rangeDegrees!.round()} degrees',
                            child: ExcludeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${DateFormat('d MMM').format(s.startedAt)} · ${s.rangeDegrees!.round()}°',
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: (s.rangeDegrees! / 180).clamp(0, 1),
                                    minHeight: 12,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const Text(
                        'Display scale: 0–180°. This is a chart scale, not a prescribed target.',
                      ),
                    ],
                  ),
                ),
                const SectionHeading('Exact measurements'),
                ContentCard(
                  child: Column(
                    children: [
                      for (final s in samples)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Wrap(
                            spacing: 24,
                            children: [
                              Text(
                                DateFormat('d MMM yyyy').format(s.startedAt),
                              ),
                              Text('${s.rangeDegrees!.round()} degrees'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${samples.length} valid samples. No recovery score or clinical conclusion is inferred.',
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
