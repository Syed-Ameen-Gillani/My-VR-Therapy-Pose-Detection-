import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../domain/motion_analysis.dart';

abstract interface class MotionDetector {
  Future<MotionPose?> detect(CameraImage image, CameraDescription camera);
  Future<void> close();
}

class MlKitMotionDetector implements MotionDetector {
  final _detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  @override
  Future<MotionPose?> detect(
    CameraImage image,
    CameraDescription camera,
  ) async {
    // Capture and display are locked to portraitUp. Never concatenate YUV planes:
    // their row/pixel strides do not describe a packed NV21 buffer.
    if (image.planes.length != 1 ||
        image.format.group != ImageFormatGroup.nv21) {
      throw StateError('Camera did not supply packed NV21 frames.');
    }
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) throw StateError('Unsupported camera rotation.');
    final poses = await _detector.processImage(
      InputImage.fromBytes(
        bytes: image.planes.single.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.single.bytesPerRow,
        ),
      ),
    );
    if (poses.length != 1) return null;
    final swapped =
        camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
    final width = (swapped ? image.height : image.width).toDouble();
    final height = (swapped ? image.width : image.height).toDouble();
    final points = <Joint, PosePoint>{};
    for (final joint in Joint.values) {
      final type = PoseLandmarkType.values.byName(joint.name);
      final p = poses.single.landmarks[type];
      if (p != null) {
        points[joint] = PosePoint(p.x / width, p.y / height, p.likelihood);
      }
    }
    return MotionPose(points, width / height);
  }

  @override
  Future<void> close() => _detector.close();
}

Future<CameraController> openMotionCamera() async {
  final cameras = await availableCameras();
  if (cameras.isEmpty) throw StateError('No camera is available.');
  final description =
      cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .firstOrNull ??
      cameras.first;
  final controller = CameraController(
    description,
    ResolutionPreset.high,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.nv21,
  );
  try {
    await controller.initialize();
    await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    return controller;
  } catch (_) {
    await controller.dispose();
    rethrow;
  }
}
