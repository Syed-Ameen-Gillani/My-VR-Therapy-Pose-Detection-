import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/features/motion/domain/motion_analysis.dart';

MotionPose arm(double degrees, {double confidence = 1}) {
  final r = degrees * pi / 180;
  return MotionPose({
    Joint.rightHip: const PosePoint(.5, .75, 1),
    Joint.rightShoulder: const PosePoint(.5, .4, 1),
    Joint.rightElbow: PosePoint(.5 + .1 * sin(r), .4 + .1 * cos(r), confidence),
    Joint.rightWrist: PosePoint(.5 + .2 * sin(r), .4 + .2 * cos(r), confidence),
  }, 1);
}

void main() {
  test('invalid aspect and confidence cannot create accepted measurements', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    expect(
      analyzer
          .process(MotionPose(arm(90).points, double.nan), Duration.zero)
          .valid,
      isFalse,
    );
    expect(const PosePoint(.5, .5, double.infinity).valid, isFalse);
    expect(
      jointAngle(
        const PosePoint(0, 1, 1),
        const PosePoint(0, 0, 1),
        const PosePoint(1, 0, 1),
        double.infinity,
      ),
      isNull,
    );
  });

  test('top feedback waits for dwell before requesting return', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    analyzer.process(arm(0), Duration.zero);
    var time = 100;
    MotionReading reading;
    do {
      reading = analyzer.process(arm(90), Duration(milliseconds: time));
      time += 100;
    } while ((reading.metric ?? 0) < 70);
    expect(reading.message, 'Hold briefly');
    for (var i = 0; i < 3; i++) {
      reading = analyzer.process(arm(90), Duration(milliseconds: time));
      time += 100;
    }
    expect(reading.message, 'Return slowly');
  });
  test('knee requires a bent-extended-held-bent cycle', () {
    final analyzer = MotionAnalyzer(MotionExercise.kneeExtension);
    for (var i = 0; i < 40; i++) {
      final r = (i < 10 || i >= 30 ? 90 : 170) * pi / 180;
      analyzer.process(
        MotionPose({
          Joint.rightHip: const PosePoint(.5, .3, 1),
          Joint.rightKnee: const PosePoint(.5, .5, 1),
          Joint.rightAnkle: PosePoint(.5 + .2 * sin(r), .5 - .2 * cos(r), 1),
        }, 1),
        Duration(milliseconds: i * 100),
      );
    }
    expect(analyzer.repetitions, 1);
    expect(analyzer.maxAngle, closeTo(170, .01));
  });

  test('angle uses the downward torso reference and correct aspect ratio', () {
    expect(
      jointAngle(
        const PosePoint(.5, .75, 1),
        const PosePoint(.5, .4, 1),
        const PosePoint(.5, .6, 1),
        .5,
      ),
      closeTo(0, .01),
    );
    expect(
      jointAngle(
        const PosePoint(0, 1, 1),
        const PosePoint(0, 0, 1),
        const PosePoint(1, 0, 1),
        .5,
      ),
      closeTo(90, .01),
    );
    expect(
      jointAngle(
        const PosePoint(0, 0, 1),
        const PosePoint(0, 0, 1),
        const PosePoint(1, 0, 1),
        1,
      ),
      isNull,
    );
  });

  test('counts a complete lowered-raised-held-return cycle only once', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    var ms = 0;
    void frames(double angle, int count) {
      for (var i = 0; i < count; i++) {
        analyzer.process(arm(angle), Duration(milliseconds: ms));
        ms += 100;
      }
    }

    frames(0, 10);
    frames(90, 15);
    frames(0, 10);
    expect(analyzer.repetitions, 1);
    frames(0, 10);
    expect(analyzer.repetitions, 1);
  });

  test('starting raised never counts an unobserved initial movement', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    for (var i = 0; i < 30; i++) {
      analyzer.process(arm(i < 20 ? 90 : 0), Duration(milliseconds: i * 100));
    }
    expect(analyzer.repetitions, 0);
  });

  test('tracking loss invalidates a partially completed repetition', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    for (var i = 0; i < 30; i++) {
      analyzer.process(arm(i < 10 ? 0 : 90), Duration(milliseconds: i * 100));
    }
    analyzer.process(null, const Duration(seconds: 3));
    for (var i = 31; i < 45; i++) {
      analyzer.process(arm(0), Duration(milliseconds: i * 100));
    }
    expect(analyzer.repetitions, 0);
  });

  test(
    'missing/low confidence frames produce failed, with no invented range',
    () {
      final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
      for (var i = 0; i < 100; i++) {
        analyzer.process(
          arm(90, confidence: .2),
          Duration(milliseconds: i * 100),
        );
      }
      expect(analyzer.status, 'failed');
      expect(analyzer.maxAngle, isNull);
      expect(analyzer.accepted, 0);
    },
  );

  test('hold duration excludes long gaps and missing frames', () {
    final analyzer = MotionAnalyzer(MotionExercise.armHold);
    analyzer.process(arm(90), Duration.zero);
    analyzer.process(arm(90), const Duration(milliseconds: 100));
    analyzer.process(arm(90), const Duration(seconds: 20));
    expect(analyzer.holdSeconds, closeTo(.1, .001));
  });

  test('balance yields a stability metric and never a degree range', () {
    final analyzer = MotionAnalyzer(MotionExercise.seatedBalance);
    const pose = MotionPose({
      Joint.leftShoulder: PosePoint(.3, .3, 1),
      Joint.rightShoulder: PosePoint(.7, .3, 1),
      Joint.leftHip: PosePoint(.35, .6, 1),
      Joint.rightHip: PosePoint(.65, .6, 1),
      Joint.nose: PosePoint(.5, .15, 1),
    }, .5);
    for (var i = 0; i < 70; i++) {
      analyzer.process(pose, Duration(milliseconds: i * 100));
    }
    expect(analyzer.status, 'ready');
    expect(analyzer.summary()['stability_percent'], closeTo(100, .01));
    expect(analyzer.maxAngle, isNull);
    expect(analyzer.repetitions, 0);
  });
}
