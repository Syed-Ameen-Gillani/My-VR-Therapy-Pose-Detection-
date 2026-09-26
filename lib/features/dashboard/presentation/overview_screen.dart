import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../../sessions/domain/therapy_session.dart';
import '../../sessions/presentation/session_row.dart';
import '../domain/dashboard_summary.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const PageHeading(
        'Your care, at a glance',
        'A little clarity for the next step in recovery.',
      ),
      AsyncContent(
        value: ref.watch(patientsProvider),
        onRetry: () => ref.invalidate(patientsProvider),
        builder: (patients) => AsyncContent(
          value: ref.watch(plansProvider),
          onRetry: () => ref.invalidate(plansProvider),
          builder: (plans) => AsyncContent(
            value: ref.watch(sessionsProvider),
            onRetry: () => ref.invalidate(sessionsProvider),
            builder: (sessions) {
              final summary = buildDashboardSummary(
                patients: patients,
                sessions: sessions,
                plans: plans,
              );
              final pending = sessions
                  .where(
                    (session) =>
                        !session.reviewed &&
                        session.analysis == AnalysisStatus.ready,
                  )
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdaptivePair(
                    first: MetricCard(
                      value: '${summary.patientCount}',
                      label: 'Patients in your care',
                      icon: Icons.people_outline,
                    ),
                    second: MetricCard(
                      value: '${summary.reviewCount}',
                      label: 'Sessions to review',
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdaptivePair(
                    first: MetricCard(
                      value: summary.adherenceValue,
                      label: 'Plan adherence estimate',
                      icon: Icons.timeline_outlined,
                    ),
                    second: MetricCard(
                      value:
                          '${summary.completedScheduledSessions}/${summary.scheduledSessions}',
                      label: 'Completed scheduled sessions',
                      icon: Icons.task_alt_outlined,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          const Color(0xFF134E4A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.spa_outlined,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Every session tells a story',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${summary.adherenceDetail}. Explore movement results and see where a patient may need your attention.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          onPressed: () => pending.isEmpty
                              ? context.go('/patients')
                              : context.push('/sessions/${pending.first.id}'),
                          child: Text(
                            pending.isEmpty
                                ? 'View patients'
                                : 'Review session',
                          ),
                        ),
                  
                    ),
                  ),
                  SectionHeading(
                    'Recent sessions',
                    action: TextButton(
                      onPressed: () => context.push('/sessions'),
                      child: const Text('See all'),
                    ),
                  ),
                  if (summary.recentSessions.isEmpty)
                    const StateMessage(
                      title: 'No sessions yet',
                      message: 'Uploaded sessions will appear here.',
                    ),
                  for (final session in summary.recentSessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: SessionRow(
                          session: session,
                          title:
                              patients
                                  .where((p) => p.id == session.patientId)
                                  .firstOrNull
                                  ?.name ??
                              'Patient unavailable',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}
