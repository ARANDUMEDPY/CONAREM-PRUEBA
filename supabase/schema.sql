-- ============================================================
-- Banco CONAREM — estructura de la base de datos (Supabase)
-- Pegar TODO este archivo en Supabase → SQL Editor → Run.
-- Se puede volver a ejecutar sin romper nada.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- 1) Perfiles de usuario (uno por cuenta)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  access_until timestamptz,          -- hasta cuándo tiene acceso
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- Crear el perfil automáticamente cuando alguien se registra
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2) Preguntas (solo las ven usuarios con acceso activo)
create table if not exists public.questions (
  id text primary key,
  area text not null,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- 3) Códigos de activación (uso único)
create table if not exists public.access_codes (
  code text primary key,
  days integer not null default 180,
  note text,
  created_at timestamptz not null default now(),
  used_by uuid references auth.users on delete set null,
  used_at timestamptz
);

-- 4) Progreso de cada usuario
create table if not exists public.progress (
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ---------- Funciones auxiliares ----------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.has_access()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin or (access_until is not null and access_until > now())
                   from public.profiles where id = auth.uid()), false);
$$;

-- Canjear un código: suma los días al acceso del usuario
create or replace function public.redeem_code(p_code text)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare c public.access_codes; new_until timestamptz;
begin
  if auth.uid() is null then raise exception 'Tenés que iniciar sesión'; end if;
  select * into c from public.access_codes where code = upper(trim(p_code)) for update;
  if not found then raise exception 'Código inválido'; end if;
  if c.used_by is not null then raise exception 'Ese código ya fue usado'; end if;
  update public.access_codes set used_by = auth.uid(), used_at = now() where code = c.code;
  update public.profiles
     set access_until = greatest(coalesce(access_until, now()), now()) + make_interval(days => c.days)
   where id = auth.uid()
   returning access_until into new_until;
  return new_until;
end $$;

-- Crear códigos (solo administradores)
create or replace function public.admin_create_codes(p_n integer, p_days integer, p_note text default null)
returns setof text language plpgsql security definer set search_path = public as $$
declare i integer; k text;
begin
  if not public.is_admin() then raise exception 'Solo administradores'; end if;
  for i in 1..least(greatest(p_n,1),200) loop
    loop
      k := upper(substr(translate(encode(extensions.gen_random_bytes(12),'base64'),'+/=0O1IL','XYZ'),1,8));
      exit when length(k) = 8 and not exists (select 1 from public.access_codes where code = k);
    end loop;
    insert into public.access_codes(code, days, note) values (k, p_days, p_note);
    return next k;
  end loop;
end $$;

-- Dar o extender acceso manualmente a un correo (solo administradores)
create or replace function public.admin_set_access(p_email text, p_until timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Solo administradores'; end if;
  update public.profiles set access_until = p_until where lower(email) = lower(trim(p_email));
  if not found then raise exception 'No existe un usuario con ese correo'; end if;
end $$;

-- ---------- Seguridad por filas (RLS) ----------
alter table public.profiles     enable row level security;
alter table public.questions    enable row level security;
alter table public.access_codes enable row level security;
alter table public.progress     enable row level security;

drop policy if exists "perfil propio o admin" on public.profiles;
create policy "perfil propio o admin" on public.profiles
  for select using (id = auth.uid() or public.is_admin());

drop policy if exists "leer preguntas con acceso" on public.questions;
create policy "leer preguntas con acceso" on public.questions
  for select using (public.has_access());
drop policy if exists "admin escribe preguntas" on public.questions;
create policy "admin escribe preguntas" on public.questions
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin ve codigos" on public.access_codes;
create policy "admin ve codigos" on public.access_codes
  for select using (public.is_admin());
drop policy if exists "admin borra codigos" on public.access_codes;
create policy "admin borra codigos" on public.access_codes
  for delete using (public.is_admin());

drop policy if exists "progreso propio" on public.progress;
create policy "progreso propio" on public.progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

grant execute on function public.redeem_code(text) to authenticated;
grant execute on function public.admin_create_codes(integer, integer, text) to authenticated;
grant execute on function public.admin_set_access(text, timestamptz) to authenticated;
grant execute on function public.has_access() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- ============================================================
-- DESPUÉS de registrarte en la web con tu correo, ejecutá esta
-- línea (cambiando el correo) para convertirte en administrador:
--
-- update public.profiles set is_admin = true where email = 'tu-correo@ejemplo.com';
-- ============================================================
