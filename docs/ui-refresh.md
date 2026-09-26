# UI finalization audit

## Findings

- The shell always displayed DEMO, including authenticated Supabase accounts.
- Login exposed a fixture-data workspace. Settings included development-phase labels and database implementation details.
- Cards, metrics and headings lacked a clear hierarchy. Selected prescription exercises needed a stronger visual state.
- Progress charts displayed numeric session indexes and did not emphasize the latest measurement. Hold charts could incorrectly use rangeDegrees when both angle and hold data existed.

## Changes

- Retained the teal identity; added a soft neutral canvas, white outlined cards, consistent rounded shapes, stronger Roboto typography, tonal icon containers and a branded navigation header.
- Added a high-contrast dashboard feature card, clearer selected-plan rows and rounded step progress.
- Refined profile/settings, library instructions and shared loading text. Removed the public fixture-data entry and unconditional DEMO badge.
- Kept internal demo repositories for existing automated tests. They are not accessible from the login UI; authenticated repositories still load Supabase data. Statistical variable names such as samples remain intentionally unchanged.
- Clarified mobile prescription copy without promising headset dispatch.
- Added date labels and latest-measurement emphasis to progress graphs. Hold charts select seconds rather than an available angle. Straight segments avoid suggesting unrecorded curved movement between sessions.

## Design reference

[Material 3 theming guidance](https://developer.android.com/codelabs/m3-design-theming): consistent semantic color pairs, type hierarchy and component shapes. No new dependency or remotely downloaded font is required.

## Validation scope

Rendered overview, plan editor, settings and progress previews using test fixtures for visual inspection. Automated coverage exercises navigation, prescription publishing, patient changes, session review, empty/error states, and layouts at 360/412 pixels with text scaling up to 200%. These checks do not substitute for live Supabase or physical-device camera validation. No SQL migration is required by this refresh.
