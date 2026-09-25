import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const PageHeading(
        'Exercise library',
        'A starting point for personalized rehabilitation.',
      ),
      const StatusBadge('Sample instructions • Not a prescription'),
      const SizedBox(height: 16),
      AsyncContent(
        value: ref.watch(exercisesProvider),
        onRetry: () => ref.invalidate(exercisesProvider),
        builder: (exercises) => Column(
          children: [
            if (exercises.isEmpty)
              const StateMessage(
                title: 'No exercises available',
                message: 'Approved exercises will appear here.',
              ),
            for (final exercise in exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Icon(
                      Icons.accessibility_new,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(exercise.name),
                    subtitle: Text(exercise.category),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/exercises/${exercise.id}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Exercise details')),
    body: SafeArea(
      child: PageBody(
        children: [
          AsyncContent(
            value: ref.watch(exerciseProvider(id)),
            onRetry: () => ref.invalidate(exercisesProvider),
            builder: (exercise) {
              if (exercise == null) {
                return const StateMessage(
                  title: 'Exercise not found',
                  message:
                      'Return to the exercise library to choose an approved exercise.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusBadge(exercise.category),
                  const SizedBox(height: 16),
                  PageHeading(
                    exercise.name,
                    'Approved exercise ID · ${exercise.id.toUpperCase()}',
                  ),
                  ContentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(exercise.instructions),
                      ],
                    ),
                  ),
                  const SectionHeading('Required setup'),
                  ContentCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.vrpano_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(exercise.equipment)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Clinical limits, tracking support, and exact movement targets must be confirmed by the supervising therapist and VR team before real use.',
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
