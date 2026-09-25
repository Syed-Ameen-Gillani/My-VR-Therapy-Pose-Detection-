import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../../../app/di/providers.dart';
import '../../plans/domain/rehabilitation_plan.dart';
import '../../sessions/domain/therapy_session.dart';
import '../application/motion_controller.dart';
import '../domain/motion_analysis.dart';

class MotionTrackingScreen extends ConsumerStatefulWidget {
  const MotionTrackingScreen({
    super.key,
    required this.patientId,
    required this.exerciseId,
  });
  final String patientId, exerciseId;
  @override
  ConsumerState<MotionTrackingScreen> createState() =>
      _MotionTrackingScreenState();
}

class _MotionTrackingScreenState extends ConsumerState<MotionTrackingScreen>
    with WidgetsBindingObserver {
  MotionController? _controller;
  RehabilitationPlan? _plan;
  String? _error;
  bool _busy = false, _finished = false, _saved = false, _background = false;
  bool _rightSide = true;
  bool _allowExit = false;
  final FlutterTts _tts = FlutterTts();
  String? _lastSpokenMessage;
  Timer? _speechTimer;
  final String _sessionId =
      'mobile_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _background = true;
      final controller = _controller;
      if (controller != null) {
        unawaited(
          controller
              .suspend()
              .then((_) {
                if (mounted) setState(() {});
              })
              .catchError((Object e) {
                if (mounted) setState(() => _error = e.toString());
              }),
        );
      }
    } else {
      _background = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechTimer?.cancel();
    unawaited(_tts.stop());
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  Future<void> _start(MotionController controller) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final patient = await ref.read(patientProvider(widget.patientId).future);
      final plan = await ref
          .read(planRepositoryProvider)
          .getPlanForPatient(widget.patientId);
      if (patient == null ||
          patient.archived ||
          plan == null ||
          plan.id == null ||
          plan.status != 'active' ||
          !plan.exerciseIds.contains(widget.exerciseId)) {
        throw StateError(
          'Choose an exercise from this patient’s active prescription.',
        );
      }
      if (_plan != null &&
          (_plan!.id != plan.id || _plan!.version != plan.version)) {
        throw StateError(
          'The prescription changed. Finish this session and start a new one.',
        );
      }
      _plan = plan;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (!mounted) return;
      _controller = controller;
      await controller.initialize();
      if (!mounted || _background) {
        await controller.suspend();
        return;
      }
      await controller.start();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Unable to start camera tracking: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(MotionController controller) async {
    setState(() => _busy = true);
    try {
      await controller.suspend();
      if (mounted) setState(() => _finished = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(MotionController controller) async {
    final plan = _plan;
    if (plan == null || controller.startedAt == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final analyzer = controller.analyzer;
      final payload = analyzer.summary()
        ..addAll({
          'duration_seconds': controller.durationSeconds,
          'last_inference_ms': controller.inferenceMilliseconds,
        });
      await ref
          .read(sessionRepositoryProvider)
          .createSession(
            TherapySession(
              id: _sessionId,
              patientId: widget.patientId,
              exerciseId: widget.exerciseId,
              startedAt: controller.startedAt!,
              durationMinutes: controller.durationSeconds ~/ 60,
              repetitions: analyzer.repetitions,
              analysis: AnalysisStatus.values.byName(analyzer.status),
              rangeDegrees: analyzer.status == 'ready'
                  ? analyzer.maxAngle
                  : null,
              aiFeedback: payload['feedback'] as String?,
              trackingQuality: analyzer.quality,
              modelVersion: payload['model_version'] as String?,
              analysisPayload: payload,
            ),
            payload: payload,
            planId: plan.id!,
            planVersion: plan.version,
          );
      ref.invalidate(sessionsProvider);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final controller = _controller;
    if (controller?.startedAt != null && !_saved) {
      try {
        await controller!.pause();
      } catch (e) {
        if (mounted) setState(() => _error = 'Camera stop failed: $e');
      }
      if (!mounted) return;
      setState(() {});
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this session?'),
          content: const Text('The unsaved motion summary will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep session'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    }
  }

  void _speak(String message) {
    if (!mounted || _background || message == _lastSpokenMessage) return;
    _lastSpokenMessage = message;
    _speechTimer?.cancel();
    _speechTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted || _background) return;
      await _tts.stop();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.speak(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = MotionExercise.fromId(widget.exerciseId);
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Motion tracking')),
        body: const Center(
          child: Text('Camera tracking is not configured for this exercise.'),
        ),
      );
    }
    final controller = ref.watch(
      motionControllerProvider((
        sessionId: _sessionId,
        exercise: exercise,
        rightSide: _rightSide,
      )),
    );
    return ValueListenableBuilder(
      valueListenable: controller.lifecycle,
      builder: (context, _, _) => _buildTracking(context, controller, exercise),
    );
  }

  Widget _buildTracking(
    BuildContext context,
    MotionController controller,
    MotionExercise exercise,
  ) {
    final camera = controller.camera;
    return PopScope(
      canPop: _allowExit || _saved || (!_busy && controller.startedAt == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: _finished
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.black,
        appBar: AppBar(
          backgroundColor: _finished
              ? Theme.of(context).appBarTheme.backgroundColor
              : Colors.black,
          foregroundColor: _finished
              ? Theme.of(context).appBarTheme.foregroundColor
              : Colors.white,
          title: Text(exercise.label),
          leading: IconButton(onPressed: _leave, icon: const Icon(Icons.close)),
        ),
        body: SafeArea(
          child: _finished
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                Text(
                  'Session summary',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Duration: ${controller.durationSeconds} seconds\n'
                  'Analysis: ${controller.analyzer.status}\nTracking quality: ${controller.analyzer.quality}\n'
                  'Accepted frames: ${controller.analyzer.accepted}/${controller.analyzer.analyzed}',
                ),
                if (exercise == MotionExercise.armHold)
                  Text(
                    'Hold: ${controller.analyzer.holdSeconds.toStringAsFixed(1)} seconds',
                  )
                else if (exercise == MotionExercise.seatedBalance)
                  Text(
                    'Stability: ${controller.analyzer.validSeconds > 0 ? (controller.analyzer.goodSeconds / controller.analyzer.validSeconds * 100).round().toString() : 'Unavailable'}%',
                  )
                else
                  Text('Repetitions: ${controller.analyzer.repetitions}'),
                if (controller.analyzer.status == 'ready' &&
                    controller.analyzer.maxAngle != null)
                  Text(
                    'Maximum angle: ${controller.analyzer.maxAngle!.round()}°',
                  ),
                const SizedBox(height: 16),
                if (!_saved)
                  FilledButton(
                    onPressed: _busy ? null : () => _save(controller),
                    child: Text(_busy ? 'Saving…' : 'Save session'),
                  )
                else
                  FilledButton(
                    onPressed: () =>
                        context.pushReplacement('/sessions/$_sessionId'),
                    child: const Text('View saved session'),
                  ),
                if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ),
                  ],
                )
                : Column(
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (camera != null && camera.value.isInitialized)
                              CameraPreview(camera)
                            else
                              const Center(
                                child: Icon(Icons.accessibility_new,
                                    size: 100, color: Colors.white54),
                              ),
                            if (camera != null && camera.value.isInitialized)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: _SkeletonPainter(
                                    controller,
                                    mirror: false,
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 16,
                              child: ValueListenableBuilder(
                                valueListenable: controller.reading,
                                builder: (context, reading, _) {
                                  if (controller.running) _speak(reading.message);
                                  return _MotionReadingOverlay(
                                    exercise: exercise,
                                    reading: reading,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 18,
                              child: Text(
                                exercise == MotionExercise.seatedBalance
                                    ? 'Keep head, shoulders and hips visible'
                                    : exercise == MotionExercise.kneeExtension
                                    ? 'Side view · hip, knee and ankle visible'
                                    : 'Keep the target side in frame',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Column(
                          children: [
                            if (controller.startedAt == null &&
                                exercise != MotionExercise.seatedBalance)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Left', style: TextStyle(color: Colors.white70)),
                                  Switch(
                                    value: _rightSide,
                                    onChanged: _busy ? null : (v) => setState(() => _rightSide = v),
                                  ),
                                  const Text('Right', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            FilledButton.icon(
                              onPressed: _busy || _background
                                  ? null
                                  : controller.running
                                  ? () => _finish(controller)
                                  : () => _start(controller),
                              icon: Icon(controller.running ? Icons.stop : Icons.play_arrow),
                              label: Text(_busy ? 'Please wait…' : controller.running ? 'Finish session' : 'Start camera'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            ),
                            if (!controller.running && controller.startedAt != null)
                              TextButton(
                                onPressed: _busy ? null : () => _finish(controller),
                                child: const Text('Review summary'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _MotionReadingOverlay extends StatelessWidget {
  const _MotionReadingOverlay({required this.exercise, required this.reading});
  final MotionExercise exercise;
  final MotionReading reading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reading.message,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (reading.metric != null)
              Text(
                exercise == MotionExercise.seatedBalance
                    ? reading.metric!.toStringAsFixed(2)
                    : '${reading.metric!.round()}°',
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.controller, {required this.mirror})
    : super(repaint: controller.pose);
  final MotionController controller;
  final bool mirror;
  static const bones = [
    (Joint.leftShoulder, Joint.rightShoulder),
    (Joint.leftHip, Joint.rightHip),
    (Joint.leftShoulder, Joint.leftElbow),
    (Joint.leftElbow, Joint.leftWrist),
    (Joint.rightShoulder, Joint.rightElbow),
    (Joint.rightElbow, Joint.rightWrist),
    (Joint.leftShoulder, Joint.leftHip),
    (Joint.rightShoulder, Joint.rightHip),
    (Joint.leftHip, Joint.leftKnee),
    (Joint.leftKnee, Joint.leftAnkle),
    (Joint.rightHip, Joint.rightKnee),
    (Joint.rightKnee, Joint.rightAnkle),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final pose = controller.pose.value;
    if (pose == null) return;
    final paint = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = 3;
    Offset position(PosePoint p) =>
        Offset((mirror ? 1 - p.x : p.x) * size.width, p.y * size.height);
    for (final (a, b) in bones) {
      final start = pose.point(a), end = pose.point(b);
      if (start != null && end != null) {
        canvas.drawLine(position(start), position(end), paint);
      }
    }
    for (final p in pose.points.values) {
      if (p.valid) canvas.drawCircle(position(p), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) =>
      mirror != oldDelegate.mirror || controller != oldDelegate.controller;
}
