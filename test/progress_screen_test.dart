import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/app/di/providers.dart';
import 'package:fyp_abdullah/app/theme/app_theme.dart';
import 'package:fyp_abdullah/features/progress/presentation/progress_screen.dart';
import 'package:fyp_abdullah/features/sessions/domain/therapy_session.dart';

TherapySession sample(String exercise, int day) => TherapySession(
  id: '$exercise-$day',
  patientId: 'p1',
  exerciseId: exercise,
  startedAt: DateTime.utc(2026, 9, day),
  durationMinutes: 1,
  repetitions: 1,
  analysis: AnalysisStatus.ready,
  rangeDegrees: exercise == 'e1' ? 80 : null,
  analysisPayload: const {'hold_seconds': 3.0},
);

Future<void> showProgress(
  WidgetTester tester,
  List<TherapySession> sessions, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 850);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientProvider('p1').overrideWith((ref) async => null),
        patientSessionsProvider('p1').overrideWith((ref) async => sessions),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const ProgressScreen(patientId: 'p1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('progress fits narrow phones at $scale text scale', (
      tester,
    ) async {
      await showProgress(tester, [
        sample('e1', 1),
        sample('e1', 2),
      ], scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Recent sessions'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('exercise selection shows trunk hold without a false trend', (
    tester,
  ) async {
    await showProgress(tester, [
      sample('e1', 1),
      sample('e1', 2),
      sample('e9', 3),
    ]);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trunk alignment hold').last);
    await tester.pumpAndSettle();
    expect(find.text('First measurement'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots, hasLength(1));
    expect(find.text('3.0s'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty progress shows a useful explanation', (tester) async {
    await showProgress(tester, []);
    expect(find.text('No comparable measurements'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
