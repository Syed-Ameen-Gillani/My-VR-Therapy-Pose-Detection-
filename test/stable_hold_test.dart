import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/features/motion/domain/stable_hold.dart';
import 'package:fyp_abdullah/features/motion/domain/motion_analysis.dart';

void main() {
  for (final exercise in MotionExercise.values) {
    test('${exercise.id}: absent/partial poses do not complete or throw', () {
      final analyzer = MotionAnalyzer(exercise);
      for (var ms = 0; ms < 5000; ms += 100) {
        analyzer.process(MotionPose({
          Joint.rightShoulder: const PosePoint(.5, .3, .99),
          Joint.rightHip: const PosePoint(.5, .6, .99),
        }, 1), Duration(milliseconds: ms));
      }
      expect(analyzer.completionHold.completed, isFalse);
    });
    test('${exercise.id}: target pose completes and is saveable', () {
      final points = <Joint, PosePoint>{
        Joint.nose: const PosePoint(.5, .1, .99),
        Joint.leftShoulder: const PosePoint(.3, .3, .99),
        Joint.leftHip: const PosePoint(.3, .6, .99),
        Joint.rightShoulder: const PosePoint(.5, .3, .99),
        Joint.rightHip: const PosePoint(.5, .6, .99),
        Joint.rightElbow: const PosePoint(.7, .3, .99),
        Joint.rightWrist: const PosePoint(.8, .3, .99),
        Joint.rightKnee: const PosePoint(.5, .75, .99),
        Joint.rightAnkle: const PosePoint(.5, .9, .99),
      };
      if (exercise == MotionExercise.elbowFlexion) {
        points[Joint.rightWrist] = const PosePoint(.55, .35, .99);
      }
      if (exercise == MotionExercise.hipFlexion) {
        points[Joint.rightKnee] = const PosePoint(.7, .4, .99);
      }
      if (exercise == MotionExercise.kneeFlexion) {
        points[Joint.rightAnkle] = const PosePoint(.65, .65, .99);
      }
      final analyzer = MotionAnalyzer(exercise);
      for (var ms = 0; ms <= 3500; ms += 100) {
        analyzer.process(MotionPose(points, 1), Duration(milliseconds: ms));
      }
      expect(analyzer.completionHold.completed, isTrue);
      expect(analyzer.status, 'ready');
    });
  }
  test('three observed seconds after acquisition complete once', () {
    final hold = StableHold();
    for (var ms = 0; ms <= 3400; ms += 100) {
      hold.update(true, Duration(milliseconds: ms));
    }
    expect(hold.completed, isTrue);
    hold.update(false, const Duration(seconds: 10));
    hold.reset();
    expect(hold.seconds, 3);
  });
  test('brief loss pauses without counting unseen time; sustained loss resets', () {
    final hold = StableHold();
    for (var ms = 0; ms <= 1000; ms += 100) {
      hold.update(true, Duration(milliseconds: ms));
    }
    final before = hold.seconds;
    hold.update(false, const Duration(milliseconds: 1100));
    hold.update(true, const Duration(milliseconds: 1200));
    expect(hold.seconds, before);
    hold.update(false, const Duration(milliseconds: 2100));
    expect(hold.seconds, 0);
    expect(hold.active, isFalse);
  });
  test('camera stall cannot complete a hold', () {
    final hold = StableHold();
    hold.update(true, Duration.zero);
    hold.update(true, const Duration(milliseconds: 300));
    hold.update(true, const Duration(seconds: 5));
    expect(hold.completed, isFalse);
    expect(hold.seconds, 0);
  });
}
