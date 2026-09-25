import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/di/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../domain/patient.dart';
import 'patient_form_dialog.dart';
import '../../sessions/presentation/session_row.dart';
import '../../motion/domain/motion_analysis.dart';

class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive patient?'),
        content: Text(
          'Archiving ${patient.name} removes them from the active list while preserving historical sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(patientRepositoryProvider).archivePatient(patient.id);
        ref.invalidate(patientsProvider);
        if (context.mounted) {
          context.pop();
          showPhaseNotice(context, '${patient.name} archived.');
        }
      } catch (e) {
        if (context.mounted) {
          showPhaseNotice(context, 'Could not archive patient: $e');
        }
      }
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => PatientFormDialog(
        title: 'Edit patient',
        submitLabel: 'Save changes',
        initialName: patient.name,
        initialGoal: patient.goal,
        onSave: (name, goal) async {
          await ref
              .read(patientRepositoryProvider)
              .updatePatient(id: patient.id, name: name, goal: goal);
          ref.invalidate(patientsProvider);
          ref.invalidate(patientProvider(patient.id));
        },
      ),
    );

    if (updated == true && context.mounted) {
      showPhaseNotice(context, 'Patient record updated.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit patient',
            onPressed: () {
              final patient = ref.read(patientProvider(id)).value;
              if (patient != null) {
                _openEditDialog(context, ref, patient);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive patient',
            onPressed: () {
              final patient = ref.read(patientProvider(id)).value;
              if (patient != null) {
                _confirmArchive(context, ref, patient);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          children: [
            AsyncContent(
              value: ref.watch(patientProvider(id)),
              onRetry: () => ref.invalidate(patientsProvider),
              builder: (patient) {
                if (patient == null) {
                  return const StateMessage(
                    title: 'Patient not found',
                    message:
                        'Return to the patient list to choose an available record.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatusBadge(
                      user != null ? 'Active patient' : 'Fictional patient',
                      tone: user != null ? StatusTone.success : StatusTone.info,
                    ),
                    const SizedBox(height: 16),
                    PageHeading(
                      patient.name,
                      'Patient ID · ${patient.id.toUpperCase()}',
                    ),
                    ContentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rehabilitation goal',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(patient.goal),
                        ],
                      ),
                    ),
                    const SectionHeading('Active plan'),
                    AsyncContent(
                      value: ref.watch(plansProvider),
                      onRetry: () => ref.invalidate(plansProvider),
                      builder: (plans) {
                        final plan = plans
                            .where((p) => p.patientId == id)
                            .firstOrNull;
                        return ContentCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                plan?.title ?? 'No plan assigned',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                plan == null
                                    ? 'No active rehabilitation plan. Prescribe a plan tailored to this patient.'
                                    : '${plan.exerciseIds.length} exercises • ${plan.scheduledSessions} scheduled sessions\nActive Prescription · Version ${plan.version}',
                              ),
                              if (plan != null && plan.status == 'active') ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Camera exercises',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                for (final exerciseId in plan.exerciseIds)
                                  if (MotionExercise.fromId(exerciseId)
                                      case final exercise?)
                                    Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.accessibility_new),
                                        ),
                                        title: Text(exercise.label),
                                        subtitle: const Text('Camera tracking'),
                                        trailing: IconButton(
                                          tooltip: 'Start exercise',
                                          onPressed: () => context.push(
                                            '/patients/$id/motion/$exerciseId',
                                          ),
                                          icon: const Icon(Icons.play_arrow),
                                        ),
                                      ),
                                    ),
                              ],
                              FilledButton(
                                onPressed: () =>
                                    context.push('/patients/$id/plan'),
                                child: Text(
                                  plan == null
                                      ? 'Prescribe plan'
                                      : 'Update prescription',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SectionHeading(
                      'Recent sessions',
                      action: TextButton(
                        onPressed: () => context.push('/patients/$id/sessions'),
                        child: const Text('View all'),
                      ),
                    ),
                    AsyncContent(
                      value: ref.watch(patientSessionsProvider(id)),
                      onRetry: () => ref.invalidate(sessionsProvider),
                      builder: (sessions) => Column(
                        children: [
                          if (sessions.isEmpty)
                            const StateMessage(
                              title: 'No sessions yet',
                              message:
                                  'Results will appear after a movement session is saved.',
                            ),
                          for (final s in sessions.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: SessionRow(
                                  session: s,
                                  title: 'Movement session',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/patients/$id/progress'),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('View progress'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
