import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/motion_camera.dart';
import '../domain/motion_analysis.dart';

final motionControllerProvider = Provider.autoDispose
    .family<
      MotionController,
      ({String sessionId, MotionExercise exercise, bool rightSide})
    >((ref, config) {
      final controller = MotionController(
        MotionAnalyzer(config.exercise, rightSide: config.rightSide),
      );
      ref.onDispose(() => unawaited(controller.close()));
      return controller;
    });

/// Camera/detector lifecycle is serialized; an in-flight frame always finishes
/// before native resources are released. Preview does not rebuild per inference.
class MotionController {
  MotionController(
    this.analyzer, {
    Future<CameraController> Function()? openCamera,
    MotionDetector Function()? createDetector,
  }) : _openCamera = openCamera ?? openMotionCamera,
       _createDetector = createDetector ?? MlKitMotionDetector.new;
  final Future<CameraController> Function() _openCamera;
  final MotionDetector Function() _createDetector;
  final MotionAnalyzer analyzer;
  final lifecycle = ValueNotifier(0);
  final pose = ValueNotifier<MotionPose?>(null);
  final reading = ValueNotifier(
    const MotionReading('Position yourself in view'),
  );
  final _clock = Stopwatch();
  CameraController? camera;
  MotionDetector? _detector;
  Future<void>? _frame;
  Future<void> _operations = Future.value();
  bool _closed = false, running = false;
  Duration _lastFrame = const Duration(seconds: -1), _lastText = Duration.zero;
  DateTime? startedAt;
  String? failure;
  double inferenceMilliseconds = 0;
  int _consecutiveErrors = 0;
  Future<void>? _closing;

  void _notifyLifecycle() {
    if (!_closed) lifecycle.value++;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operations.then((_) => action());
    _operations = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> initialize() => _serialize(() async {
    if (_closed || camera != null) return;
    final opened = await _openCamera();
    try {
      _detector = _createDetector();
      camera = opened;
    } catch (_) {
      await opened.dispose();
      rethrow;
    }
    _notifyLifecycle();
  });

  Future<void> start() => _serialize(() async {
    if (_closed || running || camera == null) return;
    failure = null;
    _consecutiveErrors = 0;
    startedAt ??= DateTime.now().toUtc();
    analyzer.breakContinuity();
    analyzer.completionHold.reset();
    _clock.start();
    running = true;
    try {
      await camera!.startImageStream((image) {
        if (!running ||
            _closed ||
            _frame != null ||
            _clock.elapsed - _lastFrame < const Duration(milliseconds: 80)) {
          return;
        }
        _lastFrame = _clock.elapsed;
        _frame = _process(image).whenComplete(() => _frame = null);
      });
    } catch (_) {
      running = false;
      _clock.stop();
      rethrow;
    } finally {
      _notifyLifecycle();
    }
  });

  Future<void> _process(CameraImage image) async {
    final timer = Stopwatch()..start();
    try {
      final detected = await _detector!.detect(image, camera!.description);
      if (!running || _closed) return;
      _consecutiveErrors = 0;
      inferenceMilliseconds = timer.elapsedMicroseconds / 1000;
      pose.value = detected;
      final next = analyzer.process(detected, _clock.elapsed);
      if (analyzer.completionHold.completed) {
        running = false;
        _clock.stop();
        reading.value = next;
        _notifyLifecycle();
        return;
      }
      if (!next.valid ||
          _clock.elapsed - _lastText >= const Duration(milliseconds: 250)) {
        reading.value = next;
        _lastText = _clock.elapsed;
      }
    } catch (e) {
      if (_closed) return;
      analyzer.process(null, _clock.elapsed);
      pose.value = null;
      _consecutiveErrors++;
      failure = 'Pose processing failed. Stop and retry the camera. ($e)';
      reading.value = MotionReading(failure!);
      if (_consecutiveErrors >= 3) {
        // Queue after this frame has completed to avoid awaiting ourselves.
        unawaited(
          suspend().catchError((Object e) {
            failure = 'Camera stopped after a tracking error: $e';
          }),
        );
      }
    }
  }

  Future<void> pause() => _serialize(_pause);
  Future<void> _pause() async {
    running = false;
    _clock.stop();
    try {
      if (camera?.value.isStreamingImages ?? false) {
        await camera!.stopImageStream();
      }
    } finally {
      await _frame;
      analyzer.breakContinuity();
      analyzer.completionHold.reset();
      if (!_closed) {
        pose.value = null;
        reading.value = MotionReading(
          failure ?? 'Paused — resume when ready',
          repetitions: analyzer.repetitions,
          holdSeconds: analyzer.holdSeconds,
        );
      }
      _notifyLifecycle();
    }
  }

  Future<void> _release() async {
    final oldCamera = camera;
    final oldDetector = _detector;
    camera = null;
    _detector = null;
    try {
      await oldCamera?.dispose();
    } finally {
      await oldDetector?.close();
      _notifyLifecycle();
    }
  }

  /// Backgrounding releases the camera; resuming requires an explicit tap.
  Future<void> suspend() => _serialize(() async {
    try {
      await _pause();
    } finally {
      await _release();
    }
  });

  int get durationSeconds => _clock.elapsed.inSeconds;
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    return _closing = _serialize(() async {
      try {
        try {
          await _pause();
        } finally {
          await _release();
        }
      } catch (e) {
        // Disposal has no caller UI; all resources were attempted above.
        failure = 'Camera cleanup failed: $e';
      } finally {
        pose.dispose();
        reading.dispose();
        lifecycle.dispose();
      }
    });
  }
}
