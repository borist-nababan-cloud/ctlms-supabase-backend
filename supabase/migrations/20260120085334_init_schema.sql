-- 1. Create PROFILES (Extends standard auth)
create table public.profiles (
  id uuid references auth.users not null primary key,
  email text,
  full_name text,
  role text check (role in ('admin', 'finance', 'field_ops')) default 'field_ops'
);

-- 2. Create SUPPLIERS
create table public.suppliers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  contact_person text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Create SHIPMENTS (The Core)
create table public.shipments (
  id uuid default gen_random_uuid() primary key,
  reference_no text not null, -- e.g. SHP-001
  supplier_id uuid references public.suppliers(id),
  barge_name text,
  draft_survey_qty numeric default 0, -- Quantity recorded by surveyor
  status text check (status in ('planned', 'loading', 'sailing', 'discharging', 'completed')) default 'planned',
  created_by uuid references public.profiles(id),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Create TRUCKING_LOGS (For Tallyman)
create table public.trucking_logs (
  id uuid default gen_random_uuid() primary key,
  shipment_id uuid references public.shipments(id) on delete cascade,
  truck_plate text not null,
  ticket_number text,
  gross_weight numeric not null,
  tare_weight numeric not null,
  net_weight numeric generated always as (gross_weight - tare_weight) stored, -- Auto calculate
  photo_url text, -- Path to storage
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Create COSTS (For HPP)
create table public.costs (
  id uuid default gen_random_uuid() primary key,
  shipment_id uuid references public.shipments(id) on delete cascade,
  category text check (category in ('purchasing', 'freight', 'discharging', 'trucking')),
  description text,
  amount numeric not null,
  is_variable boolean default false, -- True = Per Ton, False = Lump sum
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (Security best practice)
alter table public.profiles enable row level security;
alter table public.shipments enable row level security;
alter table public.costs enable row level security;
alter table public.trucking_logs enable row level security;

-- Simple Policy: Allow logged in users to do everything (We refine this later)
create policy "Allow all for authenticated" on public.shipments for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated" on public.costs for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated" on public.trucking_logs for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated" on public.suppliers for all using (auth.role() = 'authenticated');