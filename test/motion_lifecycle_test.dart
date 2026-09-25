import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_abdullah/features/motion/application/motion_controller.dart';
import 'package:fyp_abdullah/features/motion/data/motion_camera.dart';
import 'package:fyp_abdullah/features/motion/domain/motion_analysis.dart';

const description = CameraDescription(
  name: 'test',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

class FakeCamera extends CameraController {
  FakeCamera() : super(description, ResolutionPreset.medium);
  int releases = 0;
  bool failStop = false;
  @override
  Future<void> startImageStream(onAvailable) async {
    value = value.copyWith(isStreamingImages: true);
  }

  @override
  Future<void> stopImageStream() async {
    if (failStop) throw StateError('stream lost');
    value = value.copyWith(isStreamingImages: false);
  }

  @override
  Future<void> dispose() async {
    releases++;
    await super.dispose();
  }
}

class FakeDetector implements MotionDetector {
  int releases = 0;
  @override
  Future<MotionPose?> detect(
    CameraImage image,
    CameraDescription camera,
  ) async => null;
  @override
  Future<void> close() async {
    releases++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stream-stop failure still releases camera and detector', () async {
    final camera = FakeCamera()..failStop = true;
    final detector = FakeDetector();
    final controller = MotionController(
      MotionAnalyzer(MotionExercise.shoulderReach),
      openCamera: () async => camera,
      createDetector: () => detector,
    );
    await controller.initialize();
    await controller.start();
    await expectLater(controller.suspend(), throwsStateError);
    expect(camera.releases, 1);
    expect(detector.releases, 1);
    expect(controller.camera, isNull);
    expect(controller.running, isFalse);
    await controller.close();
    await controller.close();
    expect(camera.releases, 1);
    expect(detector.releases, 1);
  });

  test('failed detector construction releases the opened camera', () async {
    final camera = FakeCamera();
    final controller = MotionController(
      MotionAnalyzer(MotionExercise.shoulderReach),
      openCamera: () async => camera,
      createDetector: () => throw StateError('unavailable'),
    );
    await expectLater(controller.initialize(), throwsStateError);
    expect(camera.releases, 1);
    expect(controller.camera, isNull);
    await controller.close();
  });

  test('start and pause publish lifecycle changes to controls', () async {
    final camera = FakeCamera();
    final controller = MotionController(
      MotionAnalyzer(MotionExercise.shoulderReach),
      openCamera: () async => camera,
      createDetector: FakeDetector.new,
    );
    await controller.initialize();
    var notifications = 0;
    controller.lifecycle.addListener(() => notifications++);
    await controller.start();
    expect(controller.running, isTrue);
    await controller.pause();
    expect(controller.running, isFalse);
    expect(notifications, 2);
    expect(controller.reading.value.metric, isNull);
    await controller.close();
  });
}
