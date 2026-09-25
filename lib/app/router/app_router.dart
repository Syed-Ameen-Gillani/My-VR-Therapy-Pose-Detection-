import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../di/providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/overview_screen.dart';
import '../../features/patients/presentation/patients_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/exercises/presentation/exercises_screen.dart';
import '../../features/plans/presentation/plan_editor_screen.dart';
import '../../features/sessions/presentation/session_screens.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../core/widgets/common.dart';
import 'app_shell.dart';
import '../../features/motion/presentation/motion_tracking_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(ref.read(isAuthenticatedProvider));
  ref.listen(isAuthenticatedProvider, (_, next) => refresh.value = next);
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final access = ref.read(isAuthenticatedProvider);
      if (!access && state.uri.path != '/login') return '/login';
      if (access && state.uri.path == '/login') return '/overview';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: StateMessage(
        title: 'This page is unavailable',
        message: 'Return to your workspace.',
        onRetry: () => context.go('/overview'),
      ),
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (_, _) => const OverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                builder: (_, _) => const PatientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (_, _) => const ExercisesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/exercises/:id',
        builder: (_, s) => ExerciseDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patients/:id',
        builder: (_, s) => PatientDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patients/:id/motion/:exerciseId',
        builder: (_, s) => MotionTrackingScreen(
          patientId: s.pathParameters['id']!,
          exerciseId: s.pathParameters['exerciseId']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/plan',
        builder: (_, s) => PlanEditorScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patients/:id/sessions',
        builder: (_, s) =>
            SessionHistoryScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patients/:id/progress',
        builder: (_, s) => ProgressScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/sessions',
        builder: (_, _) => const AllSessionsScreen(),
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (_, s) => SessionDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
