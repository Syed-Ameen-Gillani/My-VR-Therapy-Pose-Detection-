import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/app/theme/app_theme.dart';
import 'package:fyp_abdullah/features/motion/application/motion_controller.dart';
import 'package:fyp_abdullah/features/motion/domain/motion_analysis.dart';
import 'package:fyp_abdullah/features/motion/presentation/motion_tracking_screen.dart';

class CompletingController extends MotionController {
  CompletingController(super.analyzer);
  final cleanup = Completer<void>();
  int suspensions = 0;

  @override
  Future<void> suspend() {
    suspensions++;
    return cleanup.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (var index = 1; index <= 10; index++) {
    final exerciseId = 'e$index';
    testWidgets('$exerciseId opens summary on completion before cleanup finishes',
        (tester) async {
      final controller = CompletingController(
        MotionAnalyzer(MotionExercise.fromId(exerciseId)!),
      );
      final speechCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async {
          speechCalls.add(call.method);
          return 1;
        },
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [motionControllerProvider.overrideWith((ref, config) => controller)],
        child: MaterialApp(theme: buildAppTheme(), home: MotionTrackingScreen(
          patientId: 'patient', exerciseId: exerciseId,
        )),
      ));
      expect(find.text('Session summary'), findsNothing);
      for (var ms = 0; ms <= 3500; ms += 100) {
        controller.analyzer.completionHold.update(true, Duration(milliseconds: ms));
      }
      expect(controller.analyzer.completionHold.completed, isTrue);
      controller.lifecycle.value++;
      await tester.pump();
      expect(find.text('Session summary'), findsOneWidget);
      expect(controller.cleanup.isCompleted, isFalse);
      expect(speechCalls, contains('stop'));
      controller.lifecycle.value++;
      await tester.pump();
      expect(controller.suspensions, 1);
      controller.cleanup.complete();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), null,
      );
    });
  }
}
