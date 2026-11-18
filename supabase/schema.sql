-- SecureVerify database schema for Supabase (PostgreSQL)
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'SecureVerify Admin',
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  batch_number text not null unique,
  manufacture_date date not null,
  expiry_date date not null,
  category text not null,
  manufacturer text not null,
  token_hash text not null,
  scan_count integer not null default 0,
  status text not null default 'active' check (status in ('active','revoked')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.scan_logs (
  id bigint generated always as identity primary key,
  product_id uuid references public.products(id) on delete set null,
  scanned_at timestamptz not null default now(),
  result text not null check (result in ('authentic','suspicious','counterfeit')),
  scanned_code text,
  user_agent text
);
create index if not exists products_batch_idx on public.products(batch_number);
create index if not exists scan_logs_scanned_at_idx on public.scan_logs(scanned_at desc);
create index if not exists scan_logs_product_idx on public.scan_logs(product_id);

alter table public.admin_users enable row level security;
alter table public.products enable row level security;
alter table public.scan_logs enable row level security;

-- Only users explicitly inserted into admin_users can manage product records and view logs.
drop policy if exists "admins read own admin record" on public.admin_users;
create policy "admins read own admin record" on public.admin_users for select to authenticated using (user_id = auth.uid());
drop policy if exists "admins manage products" on public.products;
create policy "admins manage products" on public.products for all to authenticated
using (exists(select 1 from public.admin_users a where a.user_id=auth.uid()))
with check (exists(select 1 from public.admin_users a where a.user_id=auth.uid()));
drop policy if exists "admins read scan logs" on public.scan_logs;
create policy "admins read scan logs" on public.scan_logs for select to authenticated
using (exists(select 1 from public.admin_users a where a.user_id=auth.uid()));

-- Public verification endpoint. Token is hashed and compared in the database; raw token is never stored.
create or replace function public.verify_product(p_product_id uuid, p_token text, p_user_agent text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_product public.products%rowtype;
  v_hash text;
  v_result text;
  v_count integer;
begin
  if p_product_id is null or p_token is null or length(p_token) < 20 or length(p_token) > 200 then
    insert into public.scan_logs(result, scanned_code, user_agent) values ('counterfeit','invalid-format',left(p_user_agent,500));
    return jsonb_build_object('status','counterfeit','message','The QR code is invalid or incomplete.');
  end if;
  select * into v_product from public.products where id=p_product_id;
  if not found then
    insert into public.scan_logs(result, scanned_code, user_agent) values ('counterfeit',p_product_id::text,left(p_user_agent,500));
    return jsonb_build_object('status','counterfeit','message','This product code is not registered.');
  end if;
  v_hash := encode(digest(p_token,'sha256'),'hex');
  if v_product.status <> 'active' or v_hash <> v_product.token_hash then
    insert into public.scan_logs(product_id,result,scanned_code,user_agent) values (v_product.id,'counterfeit',v_product.id::text,left(p_user_agent,500));
    return jsonb_build_object('status','counterfeit','message','The product code is invalid or has been revoked.');
  end if;
  update public.products set scan_count=scan_count+1 where id=v_product.id returning scan_count into v_count;
  if v_count > 5 then v_result := 'suspicious'; else v_result := 'authentic'; end if;
  insert into public.scan_logs(product_id,result,scanned_code,user_agent) values (v_product.id,v_result,v_product.id::text,left(p_user_agent,500));
  return jsonb_build_object(
    'status',v_result,
    'product',jsonb_build_object('name',v_product.name,'batch_number',v_product.batch_number,'manufacturer',v_product.manufacturer,'category',v_product.category,'manufacture_date',v_product.manufacture_date,'expiry_date',v_product.expiry_date),
    'scan_count',v_count,
    'message',case when v_result='suspicious' then 'The code is valid, but it has exceeded the configured scan threshold. Check the packaging and contact the manufacturer.' else 'The code matches a product registered in SecureVerify.' end
  );
end;
$$;
revoke all on function public.verify_product(uuid,text,text) from public;
grant execute on function public.verify_product(uuid,text,text) to anon, authenticated;
grant usage, select on sequence public.scan_logs_id_seq to anon, authenticated;

-- Explicit browser-role privileges (RLS still controls which rows are accessible).
grant select on public.admin_users to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select on public.scan_logs to authenticated;
