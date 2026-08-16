-- DENA Supabase schema for portal user profiles, product journey tracking,
-- and approval decisions. Run this in the Supabase SQL editor.

create table if not exists dealer_profiles (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  nik text not null unique,
  role text not null,
  code text not null,
  loa text not null,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table dealer_profiles
  add column if not exists auth_user_id uuid unique references auth.users(id) on delete set null;

create table if not exists web_mobile_pairings (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'expired')),
  approved_email text references dealer_profiles(email) on delete set null,
  approved_role text,
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

create index if not exists web_mobile_pairings_expiry_idx
  on web_mobile_pairings(status, expires_at);

create table if not exists portal_roles (
  role text primary key,
  access text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into portal_roles (role, access, sort_order)
values
  ('Dealer Distribution Admin', 'Allocate / Accept delivery', 10),
  ('Dealer Distribution Manager', 'Order / Sign delivery / Accept stock', 20),
  ('Modena Warehouse Distribution Admin', 'Confirm / Prepare / Restock', 30),
  ('Modena Warehouse Distribution Manager', 'Approve stock / Sign delivery / Manage warehouse flow', 40),
  ('Warehouse Manager', 'Approve stock / Sign delivery / Manage warehouse flow', 50),
  ('Third Party Logistics Driver', 'Pickup / Transit / Deliver', 60),
  ('Logistics Manager', 'Manage pickup / transit / delivery operations', 70)
on conflict (role) do update set
  access = excluded.access,
  sort_order = excluded.sort_order,
  active = excluded.active;

create table if not exists product_journey (
  id text primary key,
  product_id text not null,
  state text not null,
  actor text not null,
  initiator text not null,
  loa text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'awaiting_delivery')),
  approved_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table product_journey
  add column if not exists product_name text,
  add column if not exists category text,
  add column if not exists current_state text,
  add column if not exists new_state text;

create table if not exists approval_decisions (
  id text primary key,
  journey_id text not null references product_journey(id) on delete cascade,
  decision text not null check (decision in ('approved', 'rejected')),
  approver_name text not null,
  approver_role text not null,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists portal_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_email text not null references dealer_profiles(email) on delete cascade,
  journey_id text not null references product_journey(id) on delete cascade,
  sender_email text not null,
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists mobile_device_tokens (
  id uuid primary key default gen_random_uuid(),
  recipient_email text not null references dealer_profiles(email) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dealer_profiles_email_idx on dealer_profiles(email);
create index if not exists dealer_profiles_nik_idx on dealer_profiles(nik);
create index if not exists portal_roles_active_order_idx on portal_roles(active, sort_order);
create unique index if not exists dealer_profiles_email_lower_uidx
  on dealer_profiles (lower(email));
create index if not exists product_journey_status_idx on product_journey(status);
create index if not exists approval_decisions_journey_idx on approval_decisions(journey_id);
create index if not exists portal_notifications_recipient_idx
  on portal_notifications(lower(recipient_email), created_at desc);
create index if not exists mobile_device_tokens_recipient_idx
  on mobile_device_tokens(lower(recipient_email));

alter table dealer_profiles
  drop constraint if exists dealer_profiles_role_check;

alter table dealer_profiles
  add constraint dealer_profiles_role_check check (
    role in (
      'Portal Administrator',
      'Dealer Distribution Admin',
      'Dealer Distribution Manager',
      'Modena Warehouse Distribution Admin',
      'Modena Warehouse Distribution Manager',
      'Warehouse Manager',
      'Third Party Logistics Driver',
      'Logistics Manager'
    )
  );

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists dealer_profiles_updated_at on dealer_profiles;
create trigger dealer_profiles_updated_at
before update on dealer_profiles
for each row execute procedure update_updated_at_column();

drop trigger if exists portal_roles_updated_at on portal_roles;
create trigger portal_roles_updated_at
before update on portal_roles
for each row execute procedure update_updated_at_column();

drop trigger if exists product_journey_updated_at on product_journey;
create trigger product_journey_updated_at
before update on product_journey
for each row execute procedure update_updated_at_column();

drop trigger if exists mobile_device_tokens_updated_at on mobile_device_tokens;
create trigger mobile_device_tokens_updated_at
before update on mobile_device_tokens
for each row execute procedure update_updated_at_column();

drop trigger if exists approval_decisions_updated_at on approval_decisions;
create trigger approval_decisions_updated_at
before update on approval_decisions
for each row execute procedure update_updated_at_column();

create or replace function public.is_portal_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.dealer_profiles
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and role = 'Portal Administrator'
  );
$$;

create or replace function public.is_portal_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.dealer_profiles
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

grant execute on function public.is_portal_admin() to authenticated;
grant execute on function public.is_portal_staff() to authenticated;

alter table dealer_profiles enable row level security;
alter table portal_roles enable row level security;
alter table product_journey enable row level security;
alter table approval_decisions enable row level security;
alter table portal_notifications enable row level security;
alter table mobile_device_tokens enable row level security;
alter table web_mobile_pairings enable row level security;

drop policy if exists web_mobile_pairings_anon_insert_policy on web_mobile_pairings;
create policy web_mobile_pairings_anon_insert_policy
on web_mobile_pairings for insert to anon
with check (status = 'pending' and expires_at > now());

create or replace function public.get_web_mobile_pairing(pairing_id uuid)
returns table (
  status text,
  approved_email text,
  approved_role text,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select p.status, p.approved_email, p.approved_role, p.expires_at
  from public.web_mobile_pairings p
  where p.id = pairing_id
    and (p.expires_at > now() or p.status = 'approved');
$$;

grant execute on function public.get_web_mobile_pairing(uuid) to anon, authenticated;

drop policy if exists dealer_profiles_select_policy on dealer_profiles;
create policy dealer_profiles_select_policy
on dealer_profiles for select to authenticated
using (
  lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  or public.is_portal_admin()
);

drop policy if exists dealer_profiles_insert_policy on dealer_profiles;
create policy dealer_profiles_insert_policy
on dealer_profiles for insert to authenticated
with check (public.is_portal_admin());

drop policy if exists portal_roles_select_policy on portal_roles;
create policy portal_roles_select_policy
on portal_roles for select to authenticated
using (active or public.is_portal_admin());

drop policy if exists portal_roles_insert_policy on portal_roles;
create policy portal_roles_insert_policy
on portal_roles for insert to authenticated
with check (public.is_portal_admin());

drop policy if exists portal_roles_update_policy on portal_roles;
create policy portal_roles_update_policy
on portal_roles for update to authenticated
using (public.is_portal_admin())
with check (public.is_portal_admin());

drop policy if exists dealer_profiles_update_policy on dealer_profiles;
create policy dealer_profiles_update_policy
on dealer_profiles for update to authenticated
using (public.is_portal_admin())
with check (public.is_portal_admin());

drop policy if exists portal_notifications_select_policy on portal_notifications;
create policy portal_notifications_select_policy
on portal_notifications for select to authenticated
using (
  lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  or public.is_portal_admin()
);

drop policy if exists portal_notifications_insert_policy on portal_notifications;
create policy portal_notifications_insert_policy
on portal_notifications for insert to authenticated
with check (public.is_portal_staff());

drop policy if exists portal_notifications_update_policy on portal_notifications;
create policy portal_notifications_update_policy
on portal_notifications for update to authenticated
using (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')))
with check (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')));

drop policy if exists mobile_device_tokens_select_policy on mobile_device_tokens;
create policy mobile_device_tokens_select_policy
on mobile_device_tokens for select to authenticated
using (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')));

drop policy if exists mobile_device_tokens_insert_policy on mobile_device_tokens;
create policy mobile_device_tokens_insert_policy
on mobile_device_tokens for insert to authenticated
with check (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')));

drop policy if exists mobile_device_tokens_update_policy on mobile_device_tokens;
create policy mobile_device_tokens_update_policy
on mobile_device_tokens for update to authenticated
using (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')))
with check (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')));

drop policy if exists mobile_device_tokens_delete_policy on mobile_device_tokens;
create policy mobile_device_tokens_delete_policy
on mobile_device_tokens for delete to authenticated
using (lower(recipient_email) = lower(coalesce(auth.jwt() ->> 'email', '')));

drop policy if exists product_journey_select_policy on product_journey;
create policy product_journey_select_policy
on product_journey for select to authenticated
using (public.is_portal_staff());

drop policy if exists product_journey_insert_policy on product_journey;
create policy product_journey_insert_policy
on product_journey for insert to authenticated
with check (public.is_portal_staff());

drop policy if exists product_journey_update_policy on product_journey;
create policy product_journey_update_policy
on product_journey for update to authenticated
using (public.is_portal_staff())
with check (public.is_portal_staff());

drop policy if exists approval_decisions_select_policy on approval_decisions;
create policy approval_decisions_select_policy
on approval_decisions for select to authenticated
using (public.is_portal_staff());

drop policy if exists approval_decisions_insert_policy on approval_decisions;
create policy approval_decisions_insert_policy
on approval_decisions for insert to authenticated
with check (public.is_portal_staff());

insert into dealer_profiles (email, nik, role, code, loa, name)
values
  ('otjeh@fivea.eu', 'PORTAL-ADMIN', 'Portal Administrator', 'portal-admin', 'LoA4', 'Portal Administrator'),
  ('dealer.admin@gmail.com', '3201012001010001', 'Dealer Distribution Admin', 'dlr.DDD-dist-adm.BBB', 'LoA1', 'Dealer Admin'),
  ('dealer.manager@gmail.com', '3201012001010002', 'Dealer Distribution Manager', 'dlr.DDD-dist-mgr.CCC', 'LoA3', 'Dealer Manager'),
  ('warehouse.admin@gmail.com', '3201012001010003', 'Modena Warehouse Distribution Admin', 'whs-dist-adm.MMM', 'LoA2', 'Warehouse Admin'),
  ('logistics.driver@gmail.com', '3201012001010005', 'Third Party Logistics Driver', 'log.LLL-drvr.KKK', 'LoA2', 'Logistics Driver')
on conflict (email) do update set
  role = excluded.role,
  name = excluded.name,
  code = excluded.code,
  loa = excluded.loa;

insert into product_journey (
  id, product_id, state, actor, initiator, loa, status, approved_by
)
values
  ('P-1001', 'P-1001', 'Allocated', 'dlr.DDD-dist-adm.BBB', 'dealer distribution admin', 'LoA1', 'pending', null),
  ('P-1002', 'P-1002', 'Ordered', 'dlr.DDD-dist-mgr.CCC', 'dealer distribution admin', 'LoA3', 'approved', 'Dealer Manager'),
  ('P-1003', 'P-1003', 'Confirmed', 'whs-dist-adm.MMM', 'modena warehouse distribution admin', 'LoA2', 'pending', null),
  ('P-1004', 'P-1004', 'Intransit', 'log.LLL-drvr.KKK', 'third party logistics driver', 'LoA2', 'awaiting_delivery', 'Warehouse Admin')
on conflict (id) do nothing;
