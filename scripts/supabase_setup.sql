-- Ejecuta esto completo en Supabase → SQL Editor → New query → Run.
-- Antes de correrlo, reemplaza 'CAMBIA_ESTE_PIN' por tu PIN/passphrase real
-- (usa algo largo, no un PIN de 4 dígitos — es la única barrera de acceso).

create extension if not exists pgcrypto;

create table if not exists diario_sync (
  id text primary key,
  pin_hash text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Activa RLS y NO agregamos ninguna policy: esto bloquea por completo el
-- acceso directo a la tabla (SELECT/INSERT/UPDATE) para los roles anon y
-- authenticated. El único acceso posible es a través de las funciones de
-- abajo, que validan el PIN antes de leer o escribir.
alter table diario_sync enable row level security;

-- Fila única para tu bitácora personal.
insert into diario_sync (id, pin_hash, data)
values ('floi-simsat', crypt('HolasoySIMSAT2026', gen_salt('bf')), '{}'::jsonb)
on conflict (id) do nothing;

create or replace function get_diario(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row diario_sync%rowtype;
begin
  select * into v_row from diario_sync where id = 'floi-simsat';
  if v_row.id is null then
    raise exception 'no existe registro';
  end if;
  if v_row.pin_hash != crypt(p_pin, v_row.pin_hash) then
    raise exception 'PIN incorrecto';
  end if;
  return v_row.data;
end;
$$;

create or replace function save_diario(p_pin text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row diario_sync%rowtype;
begin
  select * into v_row from diario_sync where id = 'floi-simsat';
  if v_row.id is null then
    raise exception 'no existe registro';
  end if;
  if v_row.pin_hash != crypt(p_pin, v_row.pin_hash) then
    raise exception 'PIN incorrecto';
  end if;
  update diario_sync
    set data = p_data, updated_at = now()
    where id = 'floi-simsat';
end;
$$;

-- Las funciones corren como su dueño (security definer) y sí pueden tocar
-- la tabla aunque RLS la bloquee para todos los demás. Solo exponemos
-- estas dos funciones al público (anon = la app sin login real).
revoke all on function get_diario(text) from public;
revoke all on function save_diario(text, jsonb) from public;
grant execute on function get_diario(text) to anon, authenticated;
grant execute on function save_diario(text, jsonb) to anon, authenticated;

-- Para cambiar el PIN más adelante (ejecuta esto aparte cuando lo necesites,
-- reemplazando ambos valores):
-- update diario_sync set pin_hash = crypt('TU_PIN_NUEVO', gen_salt('bf')) where id = 'floi-simsat';
