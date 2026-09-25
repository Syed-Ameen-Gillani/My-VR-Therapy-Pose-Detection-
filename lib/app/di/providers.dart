import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/patients/data/supabase_patient_repository.dart';
import '../../features/patients/domain/patient.dart';
import '../../features/exercises/data/supabase_exercise_repository.dart';
import '../../features/exercises/domain/exercise.dart';
import '../../features/sessions/data/supabase_session_repository.dart';
import '../../features/sessions/domain/therapy_session.dart';
import '../../features/plans/data/supabase_plan_repository.dart';
import '../../features/plans/domain/rehabilitation_plan.dart';
import 'demo_repositories.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value ??
      ref.watch(authRepositoryProvider).currentUser;
});

final _demoProvider = Provider((ref) => DemoRepositories());
final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return SupabasePatientRepository(ref.watch(supabaseClientProvider));
  }
  return ref.watch(_demoProvider);
});
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return SupabaseExerciseRepository(ref.watch(supabaseClientProvider));
  }
  return ref.watch(_demoProvider);
});
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return SupabaseSessionRepository(ref.watch(supabaseClientProvider));
  }
  return ref.watch(_demoProvider);
});
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return SupabasePlanRepository(ref.watch(supabaseClientProvider));
  }
  return ref.watch(_demoProvider);
});
final patientsProvider = FutureProvider(
  (ref) => ref.watch(patientRepositoryProvider).getPatients(),
);
final exercisesProvider = FutureProvider(
  (ref) => ref.watch(exerciseRepositoryProvider).getExercises(),
);
final exerciseProvider = FutureProvider.autoDispose.family<Exercise?, String>((
  ref,
  id,
) async {
  final exercises = await ref.watch(exercisesProvider.future);
  return exercises.where((exercise) => exercise.id == id).firstOrNull;
});
final sessionsProvider = FutureProvider(
  (ref) => ref.watch(sessionRepositoryProvider).getSessions(),
);
final plansProvider = FutureProvider(
  (ref) => ref.watch(planRepositoryProvider).getPlans(),
);
final patientProvider = FutureProvider.autoDispose.family<Patient?, String>((
  ref,
  id,
) async {
  final patients = await ref.watch(patientsProvider.future);
  return patients.where((p) => p.id == id).firstOrNull;
});
final patientSessionsProvider = FutureProvider.autoDispose
    .family<List<TherapySession>, String>((ref, id) async {
      final sessions = await ref.watch(sessionsProvider.future);
      return sessions.where((s) => s.patientId == id).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    });

class DemoAccess extends Notifier<bool> {
  @override
  bool build() => false;
  void enter() => state = true;
  void leave() {
    ref.invalidate(patientsProvider);
    ref.invalidate(exercisesProvider);
    ref.invalidate(sessionsProvider);
    ref.invalidate(plansProvider);
    state = false;
  }
}

final demoAccessProvider = NotifierProvider<DemoAccess, bool>(DemoAccess.new);

final isAuthenticatedProvider = Provider<bool>((ref) {
  final hasDemoAccess = ref.watch(demoAccessProvider);
  final user = ref.watch(currentUserProvider);
  return hasDemoAccess || user != null;
});
