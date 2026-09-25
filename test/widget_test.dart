import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/app/app.dart';
import 'package:fyp_abdullah/app/di/demo_repositories.dart';
import 'package:fyp_abdullah/app/di/providers.dart';
import 'package:fyp_abdullah/app/router/app_router.dart';
import 'package:fyp_abdullah/app/theme/app_theme.dart';
import 'package:fyp_abdullah/core/widgets/common.dart';
import 'package:fyp_abdullah/features/auth/domain/auth_repository.dart';
import 'package:fyp_abdullah/features/dashboard/domain/dashboard_summary.dart';
import 'package:fyp_abdullah/features/progress/presentation/progress_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> get authStateChanges => Stream.value(null);

  @override
  AppUser? get currentUser => null;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class AuthenticatedFakeAuthRepository implements AuthRepository {
  AuthenticatedFakeAuthRepository(this._user) {
    _controller.add(_user);
  }

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  int signOutCount = 0;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {}

  @override
  Future<void> signOut() async {
    signOutCount++;
    _user = null;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

Future<ProviderContainer> startApp(
  WidgetTester tester, {
  DemoScenario scenario = DemoScenario.populated,
  double width = 412,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 915);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final demo = DemoRepositories(scenario: scenario, delay: Duration.zero);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      patientRepositoryProvider.overrideWithValue(demo),
      exerciseRepositoryProvider.overrideWithValue(demo),
      sessionRepositoryProvider.overrideWithValue(demo),
      planRepositoryProvider.overrideWithValue(demo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TherapyApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<(ProviderContainer, AuthenticatedFakeAuthRepository)>
startAuthenticatedApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final demo = DemoRepositories(delay: Duration.zero);
  final auth = AuthenticatedFakeAuthRepository(
    const AppUser(
      id: 'therapist_1',
      email: 'a@gmail.com',
      displayName: 'Dr. Shah',
    ),
  );
  addTearDown(auth.dispose);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      patientRepositoryProvider.overrideWithValue(demo),
      exerciseRepositoryProvider.overrideWithValue(demo),
      sessionRepositoryProvider.overrideWithValue(demo),
      planRepositoryProvider.overrideWithValue(demo),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TherapyApp()),
  );
  await tester.pumpAndSettle();
  return (container, auth);
}

Future<void> enterDemo(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Explore demo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Explore demo'));
  await tester.pumpAndSettle();
  expect(find.text('Your care, at a glance'), findsOneWidget);
}

void main() {
  test('theme keeps body and heading text legible on light surfaces', () {
    final theme = buildAppTheme();
    for (final style in [
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.headlineMedium,
      theme.textTheme.titleLarge,
    ]) {
      expect(style!.color, theme.colorScheme.onSurface);
      final foreground = style.color!.computeLuminance();
      final background = theme.colorScheme.surface.computeLuminance();
      expect(
        (background + 0.05) / (foreground + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets('demo gate, navigation, local search, patient and exit', (
    tester,
  ) async {
    final container = await startApp(tester);
    expect(find.text('Explore demo'), findsOneWidget);
    await enterDemo(tester);
    expect(find.text('Your care, at a glance'), findsOneWidget);
    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ayesha');
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('Omar Farooq'), findsNothing);
    await tester.tap(find.text('Ayesha Khan'));
    await tester.pumpAndSettle();
    expect(find.text('Shoulder mobility'), findsOneWidget);
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave demo'));
    await tester.pumpAndSettle();
    expect(find.text('Explore demo'), findsOneWidget);
    container.read(routerProvider).go('/patients/p1');
    await tester.pumpAndSettle();
    expect(find.text('Explore demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated settings show name and sign out safely', (
    tester,
  ) async {
    final started = await startAuthenticatedApp(tester);
    final container = started.$1;
    final auth = started.$2;

    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('Dr. Shah'), findsOneWidget);
    expect(find.text('a@gmail.com'), findsOneWidget);
    expect(find.text('Authenticated Therapist'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCount, 1);
    expect(find.text('Explore demo'), findsOneWidget);
  });

  testWidgets('empty and missing record states do not invent data', (
    tester,
  ) async {
    final container = await startApp(tester, scenario: DemoScenario.empty);
    await enterDemo(tester);
    container.read(routerProvider).go('/patients');
    await tester.pumpAndSettle();
    expect(find.text('No patients yet'), findsOneWidget);
    container.read(routerProvider).push('/patients/missing');
    await tester.pumpAndSettle();
    expect(find.text('Patient not found'), findsOneWidget);
  });

  testWidgets('error state has an actionable retry', (tester) async {
    final container = await startApp(tester, scenario: DemoScenario.error);
    container.read(demoAccessProvider.notifier).enter();
    container.read(routerProvider).go('/patients');
    await tester.pumpAndSettle();
    expect(find.text('Unable to load data'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load data'), findsOneWidget);
    container.dispose();
  });

  testWidgets('plan preview validates targets and protects dirty draft', (
    tester,
  ) async {
    final container = await startApp(tester);
    await enterDemo(tester);
    container.read(routerProvider).push('/patients/p3/plan');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Shoulder reach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number from 1 to 12.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '4');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Draft summary'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard preview changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Your care, at a glance'), findsOneWidget);
  });

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('screen layouts fit $width px at ${scale}x text', (
        tester,
      ) async {
        final container = await startApp(tester, width: width, scale: scale);
        await enterDemo(tester);
        for (final route in [
          '/overview',
          '/patients',
          '/patients/p1',
          '/exercises',
          '/exercises/e1',
          '/patients/p1/plan',
          '/sessions/s1',
          '/sessions/s2',
          '/patients/p1/progress',
          '/settings',
        ]) {
          container.read(routerProvider).go(route);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow or error on $route',
          );
        }
      });
    }
  }

  testWidgets('component fixture renders statuses and loading at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: PageBody(
              children: [
                for (final tone in StatusTone.values)
                  StatusBadge(tone.name, tone: tone),
                const StateMessage(
                  title: 'No records',
                  message: 'Add a record to continue.',
                ),
                AsyncContent<int>(
                  value: const AsyncLoading(),
                  builder: (n) => Text('$n'),
                  onRetry: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('progress only includes compatible valid measurements', () async {
    final demo = DemoRepositories(delay: Duration.zero);
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(demo)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      progressSamplesProvider('p1'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final samples = await container.read(progressSamplesProvider('p1').future);
    expect(samples.map((s) => s.rangeDegrees), [58, 65, 72]);
    expect(samples.map((s) => s.id).toSet().length, samples.length);
  });

  test('dashboard summary calculates known sample totals', () async {
    final demo = DemoRepositories(delay: Duration.zero);
    final summary = buildDashboardSummary(
      patients: await demo.getPatients(),
      sessions: await demo.getSessions(),
      plans: await demo.getPlans(),
    );

    expect(summary.patientCount, 4);
    expect(summary.reviewCount, 1);
    expect(summary.scheduledSessions, 7);
    expect(summary.completedScheduledSessions, 3);
    expect(summary.adherencePercent, 43);
    expect(summary.recentSessions.map((session) => session.id), [
      's1',
      's2',
      's3',
    ]);
  });

  testWidgets('overview shows adherence and review totals', (tester) async {
    await startApp(tester);
    await enterDemo(tester);

    expect(find.text('43%'), findsOneWidget);
    expect(find.text('3/7'), findsOneWidget);
    expect(find.text('Plan adherence estimate'), findsOneWidget);
    expect(find.text('Sessions to review'), findsOneWidget);
    expect(
      find.textContaining('3 of 7 scheduled sessions'),
      findsOneWidget,
    );
  });

  testWidgets('create patient and archive patient flow', (tester) async {
    final container = await startApp(tester);
    await enterDemo(tester);
    container.read(routerProvider).go('/patients');
    await tester.pumpAndSettle();

    // Tap Add patient
    await tester.tap(find.text('Add patient'));
    await tester.pumpAndSettle();

    expect(find.text('Add new patient'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Patient full name'),
      'Zainab Bibi',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rehabilitation goal'),
      'Regain full elbow extension',
    );
    await tester.tap(find.text('Save patient'));
    await tester.pumpAndSettle();

    expect(find.text('Zainab Bibi'), findsOneWidget);

    // Tap on the newly created patient
    await tester.ensureVisible(find.text('Zainab Bibi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zainab Bibi'));
    await tester.pumpAndSettle();

    expect(find.text('Regain full elbow extension'), findsOneWidget);

    // Archive patient
    await tester.tap(find.byIcon(Icons.archive_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Archive patient?'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    // Should return to patients list and Zainab Bibi should be archived
    expect(find.text('Zainab Bibi'), findsNothing);
  });

  testWidgets('edit patient updates detail and list data', (tester) async {
    final container = await startApp(tester);
    await enterDemo(tester);
    container.read(routerProvider).go('/patients/p1');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit patient'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Patient full name'),
      'Ayesha Noor',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rehabilitation goal'),
      'Practice pain-free shoulder reach',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Patient record updated.'), findsOneWidget);
    expect(find.text('Ayesha Noor'), findsOneWidget);
    expect(find.text('Practice pain-free shoulder reach'), findsOneWidget);

    container.read(routerProvider).go('/patients');
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Noor'), findsOneWidget);
  });

  testWidgets(
    'exercise detail opens from catalog and handles missing records',
    (tester) async {
      final container = await startApp(tester);
      await enterDemo(tester);
      container.read(routerProvider).go('/exercises');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shoulder reach'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise details'), findsOneWidget);
      expect(find.text('Required setup'), findsOneWidget);
      expect(find.textContaining('VR headset'), findsWidgets);

      container.read(routerProvider).go('/exercises/missing');
      await tester.pumpAndSettle();
      expect(find.text('Exercise not found'), findsOneWidget);
    },
  );

  testWidgets('prescribe plan saves and activates prescription for patient', (
    tester,
  ) async {
    final container = await startApp(tester);
    await enterDemo(tester);
    container.read(routerProvider).go('/patients/p1');
    await tester.pumpAndSettle();
    container.read(routerProvider).push('/patients/p1/plan');
    await tester.pumpAndSettle();

    final shoulderTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Shoulder reach'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    final balanceTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Seated balance'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(shoulderTile.value, isTrue);
    expect(balanceTile.value, isTrue);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Weekly session frequency'),
      findsOneWidget,
    );
    expect(find.text('4'), findsOneWidget);

    // Set sessions
    await tester.enterText(find.byType(TextFormField), '6');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify summary and publish
    expect(find.text('Draft summary'), findsOneWidget);
    await tester.tap(find.text('Publish prescription'));
    await tester.pumpAndSettle();

    // Verify returning to patient detail screen with new prescription version
    expect(find.text('Update prescription'), findsOneWidget);
  });

  testWidgets('session review requires a note and marks session reviewed', (
    tester,
  ) async {
    final container = await startApp(tester);
    await enterDemo(tester);
    container.read(routerProvider).go('/sessions/s1');
    await tester.pumpAndSettle();

    expect(find.text('Analysis ready'), findsOneWidget);
    expect(find.text('AI feedback'), findsOneWidget);
    expect(
      find.text(
        'Movement stayed controlled. Continue the current shoulder reach plan.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tracking High'), findsOneWidget);
    expect(find.text('Model demo-pose-v1'), findsOneWidget);
    await tester.ensureVisible(find.text('Save review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(
      find.text('Write a short review note before saving.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Good control today.');
    await tester.ensureVisible(find.text('Save review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();

    expect(find.text('Therapist review saved.'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
  });
}
