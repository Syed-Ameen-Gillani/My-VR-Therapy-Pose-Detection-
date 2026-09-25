import 'dart:math' as math;

enum MotionExercise {
  shoulderReach('e1', 'Shoulder reach'),
  kneeExtension('e2', 'Seated knee extension'),
  seatedBalance('e3', 'Seated balance'),
  armHold('e4', 'Arm hold');

  const MotionExercise(this.id, this.label);
  final String id, label;
  static MotionExercise? fromId(String id) =>
      values.where((e) => e.id == id).firstOrNull;
}

enum Joint {
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class PosePoint {
  const PosePoint(this.x, this.y, this.confidence);
  final double x, y, confidence;
  bool get valid =>
      x.isFinite &&
      y.isFinite &&
      confidence >= .6 &&
      confidence.isFinite &&
      confidence <= 1 &&
      x >= 0 &&
      x <= 1 &&
      y >= 0 &&
      y <= 1;
}

/// Coordinates are upright and normalized; aspect preserves angle geometry.
class MotionPose {
  const MotionPose(this.points, this.aspect);
  final Map<Joint, PosePoint> points;
  final double aspect;
  PosePoint? point(Joint joint) {
    final p = points[joint];
    return p != null && p.valid ? p : null;
  }
}

double? jointAngle(PosePoint a, PosePoint b, PosePoint c, double aspect) {
  if (!aspect.isFinite || aspect <= 0) return null;
  final ax = (a.x - b.x) * aspect, ay = a.y - b.y;
  final cx = (c.x - b.x) * aspect, cy = c.y - b.y;
  final length = math.sqrt((ax * ax + ay * ay) * (cx * cx + cy * cy));
  if (length < 1e-8) return null;
  return math.acos(((ax * cx + ay * cy) / length).clamp(-1.0, 1.0)) *
      180 /
      math.pi;
}

class MotionReading {
  const MotionReading(
    this.message, {
    this.metric,
    this.valid = false,
    this.good = false,
    this.repetitions = 0,
    this.holdSeconds = 0,
  });
  final String message;
  final double? metric;
  final bool valid, good;
  final int repetitions;
  final double holdSeconds;
}

/// Timestamp-based rules: no counting through missing frames or a side switch.
/// Thresholds are FYP starting values, not a clinical assessment.
class MotionAnalyzer {
  MotionAnalyzer(this.exercise, {this.rightSide = true});
  final MotionExercise exercise;
  final bool rightSide;
  final List<double> _window = [];
  int analyzed = 0, accepted = 0, repetitions = 0;
  double? maxAngle;
  double holdSeconds = 0, validSeconds = 0, goodSeconds = 0;
  Duration? _last, _topSince, _cycleStart;
  bool _armed = false, _raised = false;
  bool _previousGood = false;

  void breakContinuity() {
    _last = null;
    _topSince = null;
    _cycleStart = null;
    _armed = false;
    _raised = false;
    _window.clear();
    _previousGood = false;
  }

  MotionReading process(MotionPose? pose, Duration time) {
    analyzed++;
    final shoulder = rightSide ? Joint.rightShoulder : Joint.leftShoulder;
    final hip = rightSide ? Joint.rightHip : Joint.leftHip;
    final elbow = rightSide ? Joint.rightElbow : Joint.leftElbow;
    final wrist = rightSide ? Joint.rightWrist : Joint.leftWrist;
    final knee = rightSide ? Joint.rightKnee : Joint.leftKnee;
    final ankle = rightSide ? Joint.rightAnkle : Joint.leftAnkle;
    final required = switch (exercise) {
      MotionExercise.kneeExtension => [hip, knee, ankle],
      MotionExercise.seatedBalance => [
        Joint.leftShoulder,
        Joint.rightShoulder,
        Joint.leftHip,
        Joint.rightHip,
        Joint.nose,
      ],
      _ => [hip, shoulder, elbow, wrist],
    };
    if (pose == null ||
        !pose.aspect.isFinite ||
        pose.aspect <= 0 ||
        required.any((j) => pose.point(j) == null)) {
      breakContinuity();
      return MotionReading(
        'Keep the required joints visible in good light',
        repetitions: repetitions,
        holdSeconds: holdSeconds,
      );
    }
    final gap = _last == null ? Duration.zero : time - _last!;
    if (gap > const Duration(milliseconds: 500) || gap.isNegative) {
      breakContinuity();
    }
    final dt = _last == null ? 0.0 : gap.inMicroseconds / 1e6;
    _last = time;
    double? raw;
    var lean = 0.0;
    if (exercise == MotionExercise.seatedBalance) {
      final ls = pose.point(Joint.leftShoulder)!,
          rs = pose.point(Joint.rightShoulder)!;
      final lh = pose.point(Joint.leftHip)!, rh = pose.point(Joint.rightHip)!;
      final width = (ls.x - rs.x).abs();
      if (width > .04) raw = ((ls.x + rs.x - lh.x - rh.x) / 2).abs() / width;
    } else if (exercise == MotionExercise.kneeExtension) {
      raw = jointAngle(
        pose.point(hip)!,
        pose.point(knee)!,
        pose.point(ankle)!,
        pose.aspect,
      );
    } else {
      raw = jointAngle(
        pose.point(hip)!,
        pose.point(shoulder)!,
        pose.point(wrist)!,
        pose.aspect,
      );
      final s = pose.point(shoulder)!, h = pose.point(hip)!;
      final torso = (s.y - h.y).abs();
      lean = torso > .05
          ? (s.x - h.x).abs() * pose.aspect / torso
          : double.infinity;
    }
    if (raw == null || !raw.isFinite) {
      breakContinuity();
      return MotionReading(
        'Adjust the camera to show your movement clearly',
        repetitions: repetitions,
      );
    }
    accepted++;
    validSeconds += dt;
    _window.add(raw);
    if (_window.length > 5) _window.removeAt(0);
    final metric = _window.reduce((a, b) => a + b) / _window.length;
    if (exercise != MotionExercise.seatedBalance) {
      maxAngle = math.max(maxAngle ?? metric, metric);
    }
    bool good;
    String message;
    if (exercise == MotionExercise.seatedBalance) {
      good = metric <= .15;
      message = good ? 'Hold steady' : 'Return to center';
    } else if (exercise == MotionExercise.armHold) {
      good = metric >= 60 && lean <= .25;
      if (good && _previousGood) holdSeconds += dt;
      message = lean > .25
          ? 'Keep back straight'
          : good
          ? 'Hold position'
          : 'Raise arm slightly';
    } else {
      final isKnee = exercise == MotionExercise.kneeExtension;
      final upper = isKnee ? 155.0 : 70.0;
      final lower = isKnee ? 115.0 : 35.0;
      good = lean <= .25;
      message = !good
          ? 'Keep back straight'
          : metric >= upper
          ? 'Return slowly'
          : isKnee
          ? 'Extend your knee more'
          : 'Raise your arm higher';
      if (!good) {
        _armed = false;
        _raised = false;
        _topSince = null;
      } else if (metric <= lower) {
        if (_armed && _raised && _cycleStart != null) {
          if (time - _cycleStart! >= const Duration(milliseconds: 1200)) {
            repetitions++;
          } else {
            message = 'Move slower';
          }
        }
        _armed = true;
        _raised = false;
        _topSince = null;
        _cycleStart = time;
      } else if (_armed && metric >= upper) {
        _topSince ??= time;
        if (time - _topSince! >= const Duration(milliseconds: 300)) {
          _raised = true;
        }
      } else {
        _topSince = null;
      }
      if (good && metric >= upper) {
        message = !_armed
            ? 'Return to the starting position'
            : _raised
            ? 'Return slowly'
            : 'Hold briefly';
      }
    }
    if (good && _previousGood) goodSeconds += dt;
    _previousGood = good;
    return MotionReading(
      message,
      metric: metric,
      valid: true,
      good: good,
      repetitions: repetitions,
      holdSeconds: holdSeconds,
    );
  }

  double get acceptedRatio => analyzed == 0 ? 0 : accepted / analyzed;
  String get quality => acceptedRatio >= .8
      ? 'High'
      : acceptedRatio >= .5
      ? 'Medium'
      : 'Low';
  String get status => accepted == 0
      ? 'failed'
      : acceptedRatio >= .7 && validSeconds >= 5
      ? 'ready'
      : 'incomplete';
  Map<String, Object?> summary() => {
    'source': 'android_camera',
    'rule_version': 'rehab-rules-v1',
    'model_version': 'mlkit-base-stream/plugin-0.16.1',
    'tracking_quality': quality,
    'analyzed_frames': analyzed,
    'accepted_frames': accepted,
    'accepted_ratio': acceptedRatio,
    'valid_seconds': validSeconds,
    'side': rightSide ? 'right' : 'left',
    'hold_seconds': exercise == MotionExercise.armHold ? holdSeconds : null,
    'stability_percent':
        exercise == MotionExercise.seatedBalance && validSeconds > 0
        ? goodSeconds / validSeconds * 100
        : null,
    'feedback': status == 'ready'
        ? 'Camera session recorded using experimental 2D movement rules. Therapist review required.'
        : 'Tracking was insufficient for a reliable movement conclusion.',
  };
}
