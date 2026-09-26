import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/features/motion/domain/motion_analysis.dart';
import 'package:fyp_abdullah/features/sessions/domain/pose_assessment.dart';

MotionPose poseFor(MotionExercise exercise, double angle) {
  final r = angle * pi / 180;
  final points = <Joint, PosePoint>{
    Joint.nose: const PosePoint(.5, .1, 1),
    Joint.leftShoulder: const PosePoint(.3, .3, 1),
    Joint.rightShoulder: const PosePoint(.5, .3, 1),
    Joint.leftHip: const PosePoint(.3, .6, 1),
    Joint.rightHip: const PosePoint(.5, .6, 1),
    Joint.rightElbow: PosePoint(.5 + .1 * sin(r), .3 + .1 * cos(r), 1),
    Joint.rightWrist: PosePoint(.5 + .2 * sin(r), .3 + .2 * cos(r), 1),
    Joint.rightKnee: const PosePoint(.5, .75, 1),
    Joint.rightAnkle: PosePoint(.5 + .15 * sin(r), .75 - .15 * cos(r), 1),
  };
  if (exercise == MotionExercise.elbowFlexion) {
    points[Joint.rightElbow] = const PosePoint(.5, .45, 1);
    points[Joint.rightWrist] = PosePoint(.5 + .15 * sin(r), .45 - .15 * cos(r), 1);
  }
  if (exercise == MotionExercise.hipFlexion) {
    points[Joint.rightKnee] = PosePoint(.5 + .15 * sin(r), .6 - .15 * cos(r), 1);
  }
  return MotionPose(points, 1);
}

void feed(MotionAnalyzer analyzer, MotionPose? pose, {int start = 0, int count = 31}) {
  for (var i = start; i < start + count; i++) {
    analyzer.process(pose, Duration(milliseconds: i * 100));
  }
}

void main() {
  for (final exercise in MotionExercise.values) {
    test('${exercise.label}: target pose scores well', () {
      final angle = switch (exercise) {
        MotionExercise.elbowFlexion || MotionExercise.hipFlexion || MotionExercise.kneeFlexion => 60.0,
        MotionExercise.kneeExtension || MotionExercise.sitToStand => 170.0,
        _ => 90.0,
      };
      final analyzer = MotionAnalyzer(exercise);
      feed(analyzer, poseFor(exercise, angle));
      expect(analyzer.assessment.percent, closeTo(100, .01));
      expect(analyzer.assessment.rating, 'Outstanding');
      expect(PoseAssessment.fromPayload(analyzer.summary()).rating, 'Outstanding');
    });
  }

  test('high landmark confidence does not make an incorrect pose good', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    feed(analyzer, poseFor(MotionExercise.shoulderReach, 0));
    expect(analyzer.quality, 'High');
    expect(analyzer.assessment.percent, 0);
    expect(analyzer.assessment.rating, 'Very Poor');
  });

  test('partial target attainment receives an intermediate score', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    feed(analyzer, poseFor(MotionExercise.shoulderReach, 52));
    expect(analyzer.assessment.percent, closeTo(60, .01));
    expect(analyzer.assessment.rating, 'Average');
  });

  test('missing frames and long gaps cannot fabricate enough evidence', () {
    final analyzer = MotionAnalyzer(MotionExercise.shoulderReach);
    analyzer.process(poseFor(MotionExercise.shoulderReach, 90), Duration.zero);
    analyzer.process(poseFor(MotionExercise.shoulderReach, 90), const Duration(seconds: 30));
    expect(analyzer.assessment.percent, isNull);
    feed(analyzer, null, start: 301);
    expect(analyzer.assessment.percent, isNull);
  });

  test('old or invalid payload scores remain unavailable', () {
    for (final value in [null, double.nan, double.infinity, -1, 101, '90']) {
      expect(PoseAssessment.fromPayload({'pose_match_percent': value}).percent, isNull);
    }
    expect(PoseAssessment.fromPayload({}).rating, 'Not available');
    expect(const PoseAssessment(0).rating, 'Very Poor');
    expect(const PoseAssessment(29).rating, 'Very Poor');
    expect(const PoseAssessment(30).rating, 'Poor');
    expect(const PoseAssessment(44).rating, 'Poor');
    expect(const PoseAssessment(45).rating, 'Fair');
    expect(const PoseAssessment(59).rating, 'Fair');
    expect(const PoseAssessment(60).rating, 'Average');
    expect(const PoseAssessment(74).rating, 'Average');
    expect(const PoseAssessment(75).rating, 'Good');
    expect(const PoseAssessment(84).rating, 'Good');
    expect(const PoseAssessment(85).rating, 'Excellent');
    expect(const PoseAssessment(94).rating, 'Excellent');
    expect(const PoseAssessment(95).rating, 'Outstanding');
    expect(const PoseAssessment(100).rating, 'Outstanding');
  });
}
