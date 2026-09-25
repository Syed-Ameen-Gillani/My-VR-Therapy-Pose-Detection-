# Phases 0 and 1 implementation record

## Baseline

- Backup: `.backups/phase0-baseline.zip`, created before source changes.
- Flutter 3.44.9 stable, Dart 3.12.2, Java 21 from Android Studio; existing Android build targets Java 17.
- Android SDK/toolchain and licenses passed Flutter doctor. Missing Visual Studio affects Windows desktop only and is outside this Android task.
- Original analyzer and counter test passed; original debug APK built successfully.
- Original counter app installed and launched on `Pixel_6_Pro`, `emulator-5554`, Android 17/API 37. Baseline cold activity launch reported 6,930 ms in debug mode on the emulator, which is not a release performance measurement.
- User confirmed a Pixel emulator for current testing, sample data now, and replaceable real-data integration later.

## Implemented scope

- Feature-first domain/data composition and presentation structure, Riverpod injection, a persistent four-tab route shell, and a demo access gate.
- Central teal Material 3 theme, Roboto typography, reusable cards, statuses, metric tiles, adaptive pairs, loading/error/empty states.
- Overview, searchable patients, patient details, exercise catalog/details, plan editor preview, session history/details, progress preview, and settings.
- Demo fixtures support populated, empty, delayed, failed, long-name, and missing-measurement scenarios.
- Preview-only actions explicitly say that nothing is persisted. There is no pretend password authentication or silent production/mock fallback.
- Phase 1 progress bars represent exact compatible sample measurements, not a recovery score. Full analytics and date filtering remain in Phase 6.

## Screen wireframes implemented

| Screen | Reading/action order |
|---|---|
| Entry | Mark -> purpose -> demo explanation -> Explore demo |
| Overview | Heading -> patient/review counts -> review action -> recent sessions |
| Patient | Identity -> goal -> sample active plan -> session rows -> progress |
| Plan editor | Preview label -> step -> exercises -> sample session count -> review |
| Session | Date/status -> duration/repetitions -> analysis -> review-note preview |
| Progress | Metric/period -> labeled bars -> exact measurements -> interpretation limit |

The source reference board, contrast calculations, and design tokens are retained in Phase 1 of `plan.md`.

## Replacing sample data

The replacement points are `patientRepositoryProvider`, `exerciseRepositoryProvider`, `planRepositoryProvider`, and `sessionRepositoryProvider` in `lib/app/di/providers.dart`. Each exposes a pure Dart feature interface. Implement these interfaces with Supabase adapters and map external DTOs into their domain entities. Override the providers at the composition root; screen rendering does not import fixture data.

The current read contracts intentionally cover the screen foundation only. Phase 2 introduces a real auth repository and authorization gate. Phase 3/4 adds validated mutation contracts; Phase 5 finalizes source identifiers, plan/exercise versions, units, model provenance, ingestion, and paging. Stable sample IDs and explicit nullable measurements establish the direction, but unknown external payloads cannot be promised to work without mapping and contract tests.

All sample dates are fixed to September 2026 for reproducible screenshots/tests. They are not presented as live readings. Real adapters must return immutable collections and preserve explicit errors/nulls rather than silently substitute fixtures.

## Decisions and checks still requiring external input

- Supervisor-approved exercise limits and actual VR/Python payload/transport remain unconfirmed. Sample exercises are placeholders, not prescriptions.
- Supabase project/schema setup remains in Phase 2; no service-role key belongs in the mobile app or repository.
- Human review with classmates/supervisor and manual TalkBack checking remain pending.
- Physical-phone profile measurements, 20-run p95 loading/startup, 1,000-session history profiling, and repeated-cycle memory analysis remain required before declaring the performance gates met. Emulator/debug timings are not evidence that these targets pass.
- No production or Play deployment work has been added.

## Validation

See the final validation results added after the implementation checks below. Automated text-scale/layout tests supplement, rather than replace, device and accessibility review.
