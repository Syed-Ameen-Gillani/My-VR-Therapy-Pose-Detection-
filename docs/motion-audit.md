# Motion audit — 2026-09-25

This checkout contains ten exercises (e1–e10), not sixteen. Static audit and synthetic-landmark tests cover all ten. Physical-device pose accuracy, audio volume and vibration remain to be verified.

## Root causes

- Any required landmark below confidence 0.6 cleared the existing analyzer's continuity immediately. The prior hold counters were accumulated metrics, not a common three-second completion timer.
- Frame gaps above 500 ms also cleared continuity. A visible person is insufficient if required landmarks are occluded or uncertain.
- Hip flexion dereferenced the knee without requiring it in validation. Missing knee data could throw and suspend processing after repeated errors.
- Speech was scheduled from widget builds, with no finish/background generation guard. Native configuration awaits could allow stale speech to start later.
- There was no shared automatic completion, start/completion haptic feedback or three-second progress display.

## Shared completion behavior

Confidence remains 0.6: uncertain measurements are not counted. A 300 ms acquisition period precedes a three-second observed hold. Brief bad frames pause progress; more than 800 ms since the last valid target resets it. Intervals above 400 ms are not counted. Five-degree angle hysteresis (and wider balance/alignment tolerance) applies while holding. Pausing/backgrounding resets unfinished completion progress; completed state is latched.

All exercises share completion signaling. Controller stops accepting frames before notifying completion. Screen switches immediately to summary, cancels pending speech and guards every asynchronous speech request before speaking. Camera cleanup is serialized and performed after the current frame. Start and completion use system audio cues and haptics; device settings can mute them. Save remains an explicit action.

## Exercise checks

| ID | Required measurement | Entry target for three-second hold |
|---|---|---|
| e1 shoulder reach | Hip–shoulder–wrist, elbow visible | At least 70 degrees; upright trunk |
| e2 knee extension | Hip–knee–ankle | At least 155 degrees |
| e3 seated balance | Both shoulders/hips, nose | Normalized center displacement at most 0.15 |
| e4 arm hold | Hip–shoulder–wrist, elbow visible | At least 60 degrees; upright trunk |
| e5 elbow flexion | Shoulder–elbow–wrist; hip for trunk | At most 70 degrees; upright trunk |
| e6 seated hip flexion | Shoulder–hip–knee | At most 80 degrees; upright trunk |
| e7 knee flexion | Hip–knee–ankle | At most 90 degrees |
| e8 shoulder abduction | Hip–shoulder–elbow, wrist visible | At least 75 degrees; upright trunk |
| e9 trunk alignment | Both shoulders/hips, nose | Normalized lateral lean at most 0.25 |
| e10 sit to stand | Hip–knee–ankle | At least 155 degrees |

Targets are prototype engineering rules, not individualized prescriptions. The new task is holding a target pose; it does not require a full repetition before completion. Existing repetition metrics remain separate and may be zero. A straight-knee pose alone does not prove a sit-to-stand transition or distinguish standing from a straight seated leg. Shoulder forward/side motions require the instructed camera view; 2D landmarks cannot reliably distinguish depth.

## Other findings and changes

- Three-second completion now produces ready analysis; previously ready required five valid seconds. New results use rehab-hold-v2 to avoid mixing them with old rules in progress comparisons.
- Trunk alignment and sit-to-stand were missing from progress eligibility despite having cards; restored their inclusion.
- Exercise-details category badge overflow at 200% text now wraps within the remaining row width.

## Remaining limitations / next validation

ML Kit stream mode tracks the most prominent person and cannot reliably report multiple people. The returned list length is not a multi-person safety check. Keep one person in view; reliable multi-person gating requires a separate person detector. Occlusion, camera perspective, motion blur and identity switches remain model limitations.

Verify every exercise on a phone in the instructed camera view, including low light, partial visibility, brief departure, background/resume and completion during speech. Calibrate thresholds with the supervising therapist. Consider a sit/stand transition classifier and camera-view validation before claiming exercise-form accuracy. The existing legacy repetition rules for the added flexion exercises need separate movement-cycle validation; target-hold completion uses explicitly lower-angle flexion targets.
