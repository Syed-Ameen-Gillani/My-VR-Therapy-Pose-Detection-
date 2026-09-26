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

class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  bool _showAllExercises = false;


  Future<void> _openEditDialog(BuildContext context, Patient patient) async {
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
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit patient',
            onPressed: () {
              final patient = ref.read(patientProvider(widget.id)).value;
              if (patient != null) {
                _openEditDialog(context, patient);
              }
            },
          ),
         
        ],
      ),
      body: SafeArea(
        child: PageBody(
          children: [
            AsyncContent(
              value: ref.watch(patientProvider(widget.id)),
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
                            .where((p) => p.patientId == widget.id)
                            .firstOrNull;
                        final hasExercises =
                            plan != null &&
                            plan.status == 'active' &&
                            plan.exerciseIds.isNotEmpty;
                        final hasManyExercises =
                            hasExercises && plan.exerciseIds.length > 3;
                        final visibleExercises = hasExercises
                            ? (_showAllExercises
                                  ? plan.exerciseIds
                                  : plan.exerciseIds.take(3).toList())
                            : const <String>[];

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
                             const SizedBox(height: 8),
                              if (hasExercises) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Prescribed exercises (${plan.exerciseIds.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    if (hasManyExercises)
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showAllExercises =
                                                !_showAllExercises;
                                          });
                                        },
                                        child: Text(
                                          _showAllExercises
                                              ? 'Show less'
                                              : 'See all',
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  alignment: Alignment.topCenter,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final exerciseId in visibleExercises)
                                        if (MotionExercise.fromId(exerciseId)
                                            case final exercise?)
                                          Card(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: ListTile(
                                              leading: const CircleAvatar(
                                                child: Icon(
                                                  Icons.accessibility_new,
                                                ),
                                              ),
                                              title: Text(exercise.label),
                                              subtitle: const Text(
                                                'Camera tracking',
                                              ),
                                              trailing: IconButton(
                                                tooltip: 'Start exercise',
                                                onPressed: () => context.push(
                                                  '/patients/${widget.id}/motion/$exerciseId',
                                                ),
                                                icon: const Icon(
                                                  Icons.play_arrow,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                                // if (hasManyExercises) ...[
                                //   OutlinedButton.icon(
                                //     onPressed: () {
                                //       setState(() {
                                //         _showAllExercises =
                                //             !_showAllExercises;
                                //       });
                                //     },
                                //     icon: Icon(
                                //       _showAllExercises
                                //           ? Icons.expand_less
                                //           : Icons.expand_more,
                                //       size: 18,
                                //     ),
                                //     label: Text(
                                //       _showAllExercises
                                //           ? 'Show less'
                                //           : 'See all (${plan.exerciseIds.length} exercises)',
                                //     ),
                                //   ),
                                //   const SizedBox(height: 8),
                                // ],
                                const SizedBox(height: 8),
                              ],
                             
                              FilledButton(
                                onPressed: () =>
                                    context.push('/patients/${widget.id}/plan'),
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
                        onPressed: () =>
                            context.push('/patients/${widget.id}/sessions'),
                        child: const Text('View all'),
                      ),
                    ),
                    AsyncContent(
                      value: ref.watch(patientSessionsProvider(widget.id)),
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
                      onPressed: () =>
                          context.push('/patients/${widget.id}/progress'),
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
