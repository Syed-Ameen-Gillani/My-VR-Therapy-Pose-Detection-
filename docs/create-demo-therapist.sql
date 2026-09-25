create extension if not exists pgcrypto;

alter table profiles add column if not exists email text;
alter table profiles add column if not exists display_name text;
alter table profiles add column if not exists role text not null default 'therapist';
alter table profiles add column if not exists enabled boolean not null default true;
alter table profiles add column if not exists created_at timestamptz not null default now();

do $$
declare
  user_email text := 'a@gmail.com';
  user_password text := 'Ameen123';
  user_name text := 'Dr. Shah';
  new_user_id uuid;
begin
  select id into new_user_id
  from auth.users
  where email = user_email;

  if new_user_id is null then
    new_user_id := gen_random_uuid();

    insert into auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    )
    values (
      new_user_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      user_email,
      crypt(user_password, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', user_name, 'role', 'therapist'),
      now(),
      now(),
      '',
      '',
      '',
      ''
    );

    insert into auth.identities (
      id,
      user_id,
      provider_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    )
    values (
      gen_random_uuid(),
      new_user_id,
      new_user_id::text,
      jsonb_build_object(
        'sub', new_user_id::text,
        'email', user_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      now(),
      now(),
      now()
    );
  end if;

  insert into profiles (id, email, display_name, role, enabled)
  values (new_user_id, user_email, user_name, 'therapist', true)
  on conflict (id) do update
  set email = excluded.email,
      display_name = excluded.display_name,
      role = excluded.role,
      enabled = true;
end;
$$;
