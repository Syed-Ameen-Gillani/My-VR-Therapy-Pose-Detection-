-- Run in Supabase SQL Editor. Adds/enables e5-e10 only.
-- Existing prescriptions, sessions and the original four exercises are untouched.
begin;
insert into public.exercises
  (id, name, category, instructions, equipment, version, enabled)
values
  ('e5', 'Elbow flexion', 'Upper body',
   'Side view: bend your elbow toward your shoulder. Keep shoulder, elbow, wrist and hip visible. Hold the target pose for three seconds.',
   'Android phone on a stable stand', 1, true),
  ('e6', 'Seated hip flexion', 'Lower body',
   'Sit side-on and lift your knee. Keep shoulder, hip and knee visible. Hold the target pose for three seconds.',
   'Stable chair and Android phone', 1, true),
  ('e7', 'Seated knee flexion', 'Lower body',
   'Sit side-on and bend your knee back. Keep hip, knee and ankle visible. Hold the target pose for three seconds.',
   'Stable chair and Android phone', 1, true),
  ('e8', 'Shoulder abduction', 'Upper body',
   'Face the camera and raise your arm sideways with your trunk upright. Keep hip and whole arm visible. Hold the target pose for three seconds.',
   'Android phone on a stable stand', 1, true),
  ('e9', 'Trunk alignment hold', 'Posture',
   'Face the camera and sit upright with both shoulders above your hips. Keep head, shoulders and hips visible. Hold for three seconds.',
   'Stable chair and Android phone', 1, true),
  ('e10', 'Sit to stand', 'Functional movement',
   'Side view: stand upright from a stable chair. Keep hip, knee and ankle visible. Hold the upright pose for three seconds.',
   'Stable chair and Android phone', 1, true)
on conflict (id) do update set enabled = true;
commit;

-- Expect six enabled rows. Restart the app to refresh its cached catalog.
select id, name, enabled from public.exercises
where id in ('e5', 'e6', 'e7', 'e8', 'e9', 'e10') order by name;
