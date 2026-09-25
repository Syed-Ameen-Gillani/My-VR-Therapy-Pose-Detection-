# Android motion tracking — Phase X

## Setup and entry

1. Run `supabase-motion.sql` in the project's Supabase SQL Editor after the existing setup. It is additive and can be rerun. No remote migration has been performed automatically.
2. Fully rebuild/restart the Android app; hot reload cannot install camera/ML Kit native plugins.
3. Open a patient with an active prescription. Prescribe one of `e1` shoulder reach, `e2` knee extension, `e3` balance, or `e4` arm hold.
4. Tap **Track [exercise]**, select the exercising side if relevant, then start the camera. Grant camera permission. Microphone permission is not needed.
5. Finish, inspect the summary and save. Saved results use the ordinary session/review flow. A failed save retains the summary and session ID for retry while this screen remains open.

The sample repository supports the same recording flow in demo mode; its saved sessions are in-memory only. The authenticated flow writes Supabase. No frames or video are stored or uploaded.

## Implementation

- `motion/domain/motion_analysis.dart`: normalized landmark models, aspect-corrected 2D angle math, exercise-specific analysis, continuity and summary rules. No plugin imports.
- `motion/data/motion_camera.dart`: portrait camera source, explicit packed NV21 validation, ML Kit adapter, upright normalized landmark conversion. Unexpected formats fail visibly rather than concatenating incompatible YUV planes.
- `motion/application/motion_controller.dart`: auto-disposed Riverpod session owner; serialized initialization/pause/disposal; at most one inference at a time; 80 ms minimum input spacing; a separate overlay notifier; UI feedback at about 4 Hz.
- `motion/presentation/motion_tracking_screen.dart`: setup, side selection, preview/skeleton, live feedback, summary, retry and unsaved-exit confirmation.
- Existing session repository: mobile insert with patient, therapist, exercise and prescription-version linkage. Retries use the same random ID and ignore duplicate inserts.
- `supabase-motion.sql`: requires an enabled therapist, their non-archived patient, an enabled exercise and an owned prescription version containing that exercise.

Only the camera page holds native resources. Moving to the background pauses measurement and releases them. Resuming requires a tap. A pending inference completes before the detector closes. Never count across a tracking gap or switch body side automatically.

## Rules and limitations

Landmark confidence threshold is 0.6. Invalid required joints clear the metric window and incomplete repetition. Five accepted frames smooth the metric; gaps over 500 ms reset movement continuity. This is a neural pose detector followed by deterministic movement rules, not a separately trained correct/incorrect posture model.

| Exercise | Metric and counting |
|---|---|
| Shoulder reach | Angle hip–shoulder–wrist: lowered <=35°, raised >=70°, 300 ms top dwell, complete return and >=1.2 second cycle |
| Knee extension | Angle hip–knee–ankle: bent <=115°, extended >=155°, same dwell/cycle guards; use a side view |
| Balance | Absolute shoulder/hip midpoint horizontal offset divided by shoulder width; centered <=0.15; stability is centered accepted time / accepted time |
| Arm hold | Elevation >=60° with acceptable trunk lean; accumulate time only across adjacent valid frames |

Shoulder/hold trunk lean is aspect-corrected horizontal displacement / vertical torso displacement, limited to 0.25. Side choice is anatomical. These are prototype starting values requiring therapist-agreed real-device tuning. 2D angles depend on view; moving toward the camera does not yield a reliable angle. The shoulder exercise must move in the image plane.

Quality is the accepted fraction of analyzed frames: high >=80%, medium >=50%, otherwise low. Skipped/busy frames are not included. `ready` requires >=70% accepted frames and >=5 valid seconds; otherwise `incomplete`, or `failed` if none were accepted. Insufficient tracking saves no range measurement. `ready` describes tracking sufficiency, not correct exercise execution. Balance/hold sessions do not generate artificial repetitions.

The detector tracks a primary person and cannot guarantee detecting additional people. Lighting/distance problems appear as missing or unreliable landmarks, not a diagnosed cause. Use one person, a stable phone and a view showing the required joints. Raw landmarks, video, classifier training, speech guidance and sit-to-stand are not included.

## Acceptance still pending

- Physical Android phone: permission denial/retry; front-camera mirror alignment; portrait orientation; background/resume; leaving while inference runs.
- Each exercise: observed repetitions/holds and angle checks against manual reference; noise and occlusion; different body sizes and distances.
- Remote Supabase: run migration, save/retry a summary, review it, inspect progress, reject another therapist's patient/plan.
- Five-minute profile-mode run: device/build/lens/resolution/lighting, accepted ratio, inference latency distribution, feedback latency, heat and battery. The app currently records the last inference time, not a benchmark distribution.

Do not claim measured superiority over Python/YOLO or clinical validity before collecting comparison data.

References used for the integration: [ML Kit Android pose detection](https://developers.google.com/ml-kit/vision/pose-detection/android), [Flutter ML Kit input-image requirements](https://github.com/flutter-ml/google_ml_kit_flutter/blob/develop/packages/google_mlkit_commons/README.md), and the project's `POSE_DETECTION_GUIDE.md`.
