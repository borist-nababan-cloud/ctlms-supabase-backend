# NSM Backend - Project Summary

> Last Updated: 2026-07-14
> Status: Active Development (Cloud Linked: ufazhiohzejkrgzioupn)
> Supabase CLI: v2.102.0 (v2.109.1 available - update pending)

---

## Project Overview

NSM Backend is a **Coal Logistics Management System** built on Supabase (PostgreSQL 17). It manages coal procurement, shipping, inventory tracking, sales orders, and delivery operations with multi-company support.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Database** | PostgreSQL 17 (via Supabase) |
| **Authentication** | Supabase Auth with custom user profiles |
| **Storage** | Supabase Storage (tickets, company logos) |
| **Edge Functions** | Deno 2 runtime |
| **Local Development** | Supabase CLI v2.102.0 (v2.106.0 available - update pending) with Docker |
| **Cloud Project** | ufazhiohzejkrgzioupn (linked) |
| **Git Repository** | https://github.com/borist-nababan-cloud/ctlms-supabase-backend |

---

## Database Schema

### Core Master Tables
| Table | Purpose |
|-------|---------|
| `master_companies` | Multi-company management with logo and hex_color support |
| `master_partners` | Suppliers, customers, transporters |
| `master_products` | Coal products (SKU, pricing, units) |
| `master_warehouse` | Warehouse/facility locations |
| `master_blending` | Blending configurations with nama_blending and cost |
| `master_type_production` | Production types with nama_type and cost |
| `user_roles` | 8 predefined roles (see below) |
| `user_profiles` | User profiles linked to `auth.users` |

### Operational Tables
| Table | Purpose |
|-------|---------|
| `shipments` | Incoming coal shipments with financial tracking (company_id, issue_date, loading_date, qty_loading, harga, ppn_tax, pph_tax, disc, is_completed, jenis_batu, asal_batu, invoice_no, quantity, id_tcp) |
| `trucking_logs` | Truck delivery records (core tally table) |
| `sales_orders` | Sales orders to customers with company isolation and completion lock |
| `delivery_orders` | Individual delivery records with SJ numbering, transporter_id, adjust_weight, weights, internal_product_id, and auto-inventory deduction |
| `delivery_order_items` | Line items for delivery orders (per truck/item with product, type production, blending, product_net, produk_net, ticket_number, weights, photos) |
| `do_sequences` | Sequential number tracker for Surat Jalan (SJ) per company |
| `inventory_ledger` | Inventory transaction log (with company_id support) |
| `inventory_adjustments` | Stock adjustment request system with approval workflow (current_stock_snapshot, actual_stock, status, notes, created_by, approved_by, rejection_notes) |
| `tcp_input` | TCP (Total Coal Production) tracking with status sync to inventory_adjustments (tcp_value, total_in, total_out, actual_stock, inventory_adjustment_id, status, rejection_notes) |
| `do_cancellation_requests` | DO cancellation/modification request system with approval workflow (do_id, request_type, company_id, status, created_by, approved_by, reason) |
| `suppliers` | Supplier details |
| `costs` | Cost tracking |

### Key Views
- `view_inventory_current` - Current stock levels per product (grouped by company_id)
- `view_shipment_summary` - Shipment progress with variance tracking (includes variance_percentage calculation)
- `view_shipments_detailed` - Full shipment details with supplier, product, SKU, and company info
- `view_trucking_summary` - Trucking logs with shipment context
- `view_delivery_report` - Comprehensive delivery reporting with customer/supplier context, type_blending, and type_production
- `view_ledger_details` - Inventory ledger with conditional joins based on transaction_type (PEMBELIAN shows supplier/vessel, SALES shows customer/sj_number)
- `view_adjustment_report` - Inventory adjustments with shipment context, supplier info, and user/approver details
- `view_tcp_report` - TCP input analysis with shipment context, qty_invoice, qty_tcp, stock_system, actual_stock, and selisih

---

## User Roles System

| ID | Role Name |
|----|-----------|
| 1 | Super Administrator |
| 2 | Administrator |
| 3 | Manager |
| 4 | Supervisor |
| 5 | Staff |
| 6 | Operator |
| 7 | Unassigned |
| 8 | Super User |

---

## Important Enum/Type Constraints

### Partner Types
`SUPPLIER`, `CUSTOMER`, `TRANSPORTER`, `OTHER`

### Product Types
`INTERNAL_RAW`, `PUBLISHED_FINISHED`

### Delivery Types
`DIRECT_BARGE`, `STOCKPILE`, `SCHEDULED`

### Inventory Transaction Types
`TALLY_IN`, `SALES_OUT`, `ADJUSTMENT`, `BLENDING`, `PEMBELIAN`, `SALES_STOCK_PILE`, `TCP_INPUT`, `RETURN`, `SALES_LOOSING`

### Inventory Locations
`STOCKPILE`, `BARGE`, `CUSTOMER`

### Sales Order Status
`DRAFT`, `CONFIRMED`, `COMPLETED`, `CANCELLED`

### Shipment Status
`planned`, `loading`, `sailing`, `discharging`, `completed`

---

## Edge Functions

### `ocr-ticket/index.ts`
Processes weighbridge ticket images using AI vision to extract:
- Truck plate number
- Ticket number
- Gross, tare, and net weights

**Provider**: OpenRouter API with Google Gemini 2.5 Flash (updated from `google/gemini-2.0-flash-001` in June 2026 to resolve deprecated endpoints)
**Secret**: `OPENROUTER_API_KEY` (configured in Supabase Secrets)
**Deployment (Cloud/Staging)**: Run `npx supabase functions deploy ocr-ticket` from the backend directory to push updates.

## RPC Functions

### `revert_inventory_on_delete()`
Automatically restores inventory when a delivery_order_item is deleted.

**Created**: June 16, 2026
**Trigger**: `trg_revert_inventory_on_delete` on `delivery_order_items` (AFTER DELETE)
**Behavior**:
1. Fetches `company_id` from parent `delivery_orders` header
2. Inserts `ADJUSTMENT` entry into `inventory_ledger` with positive `qty_change`
3. Uses `produk_net` as the reversal quantity
4. Notes format: 'REVERSAL: Deleted Item Truck {truck_plate}'

**Security**: SECURITY DEFINER (triggered automatically on DELETE)

### `get_next_so_number()`
Generates sequential Sales Order numbers in format `SO/YYMM/XXXXX`.

**Created**: June 10, 2026
**Format**: `SO/YYMM/XXXXX` (e.g., `SO/2606/00001`)
**Behavior**:
- Month (`MM`) is displayed in the number for clarity
- Sequence (`XXXXX`) resets **yearly**, not monthly
- Example: January 2026 → `SO/2601/00001`, February 2026 → `SO/2602/00002`, January 2027 → `SO/2701/00001`
**Security**: Can be called from frontend with RLS

### `generate_sj_number(p_company_id uuid)`
Generates sequential Surat Jalan numbers formatted as 4-digit strings (0001, 0002, etc.).

**Created**: June 7, 2026
**Actions**:
1. Locks the sequence row for the company
2. Increments and returns the next number
3. Uses `FOR UPDATE` to prevent duplicate numbers

**Security**: Uses row-level locking to prevent race conditions

### `complete_shipment(p_shipment_id uuid)`
Manually completes a shipment and adds inventory entry. Returns JSONB response.

**Created**: June 5, 2026
**Replaces**: Automatic trigger-based completion
**Actions**:
1. Validates shipment is not already completed
2. Sets `is_completed = true` and `status = 'completed'`
3. Adds `TALLY_IN` entry to `inventory_ledger`
4. Returns `{"success": true, "message": "..."}`

**Security**: SECURITY DEFINER (can be called from frontend with RLS)

### `approve_inventory_adjustment(p_adjustment_id uuid)`
Approves an inventory adjustment request and creates ledger entry.

**Created**: June 17, 2026
**Actions**:
1. Validates request status is `ON_REQUEST`
2. Calculates delta: `actual_stock - current_stock_snapshot`
3. Updates status to `APPROVED` and sets `approved_by`
4. Inserts `ADJUSTMENT` entry into `inventory_ledger` with delta value

**Security**: SECURITY DEFINER (can be called from frontend with RLS)

### `sync_tcp_status()`
Synchronizes TCP input status with inventory adjustment status.

**Created**: June 17, 2026
**Trigger**: `trg_sync_tcp_status` on `inventory_adjustments` (AFTER UPDATE)
**Behavior**:
- Syncs `status` and `rejection_notes` from `inventory_adjustments` to `tcp_input`
- Fires when status or rejection_notes changes

**Security**: SECURITY DEFINER (triggered automatically on UPDATE)

### `approve_do_cancellation()`
Handles automatic execution when DO cancellation request is approved.

**Created**: July 10, 2026
**Trigger**: `trg_approve_do_cancellation` on `do_cancellation_requests` (AFTER UPDATE)
**Behavior**:
- Fires when status changes from ON_REQUEST to APPROVED
- **Ganti Kendaraan**: Updates truck_plate and transporter_id in delivery_orders
- **Ganti Sales Order**: Updates sales_order_id in delivery_orders
- **Pengembalian Stok (Total)**: Inserts RETURN entries to inventory_ledger for all DO items

**Note**: Function currently uses English request_type values, needs update to Indonesian

**Security**: SECURITY DEFINER (triggered automatically on UPDATE)

---

## Storage Buckets

| Bucket ID | Purpose | Public |
|----------|---------|--------|
| `tickets` | Weighbridge ticket images | Yes |
| `company-logos` | Company logo images | Yes |

### Storage Policies (company-logos)
- **Public Read Access**: Anyone can read logos
- **Authenticated Upload Access**: Authenticated users can upload

---

## Recent Database Changes (June 17, 2026)

### Schema Enhancements
1. **Inventory Adjustment Request System** ✅
   - Created `inventory_adjustments` table for stock adjustment workflow
   - Columns: id, company_id, product_id, current_stock_snapshot, actual_stock, status (ON_REQUEST/APPROVED/REJECTED), notes, created_by, approved_by, created_at, rejection_notes
   - Created `approve_inventory_adjustment(p_adjustment_id uuid)` RPC function
   - Function calculates delta and inserts ADJUSTMENT ledger entry
   - Migration: `20260617000000_add_inventory_adjustments_table_and_function.sql`

2. **RLS Policy Updates** ✅
   - Enabled RLS on `delivery_order_items` table
   - Enabled RLS on `do_sequences` table
   - Created policies for authenticated users (full access)
   - Migration: `20260617000001_enable_rls_on_delivery_order_items_and_do_sequences.sql`

3. **Foreign Key Constraints** ✅
   - Added FK constraints for `created_by` and `approved_by` to `user_profiles`
   - Enables PostgREST to auto-resolve joins
   - Migration: `20260617000002_add_inventory_adjustments_user_profiles_fk.sql`

4. **TCP Input System** ✅
   - Created `tcp_input` table for TCP (Total Coal Production) tracking
   - Added `id_tcp` column to `shipments` table (1:1 relationship)
   - Columns: tcp_value, total_in, total_out, actual_stock, current_stock_snapshot, inventory_adjustment_id, status, rejection_notes
   - Enabled RLS with authenticated user access
   - Migration: `20260617000003_add_tcp_input_table_and_shipments_fk.sql`

5. **TCP Status Sync Enhancement** ✅
   - Added `rejection_notes` to `inventory_adjustments` and `tcp_input`
   - Added `status` to `tcp_input` with CHECK constraint
   - Created `sync_tcp_status()` function and trigger
   - Migration: `20260617000004_add_rejection_notes_and_tcp_status_sync.sql`

6. **Git & Cloud Deployment** ✅
   - Created commit `89f1bfe` and pushed to GitHub
   - Successfully pushed 5 migrations to cloud database

---

## Recent Database Changes (June 10, 2026)

### Schema Enhancements
1. **Sales Order Number Generator** ✅ (Created locally)
   - Created `get_next_so_number()` function for auto-generating sequential SO numbers
   - Format: `SO/YYMM/XXXXX` (e.g., `SO/2606/00001`)
   - Sequence resets yearly, not monthly
   - Month is displayed for clarity but sequence continues across months

2. **Delivery Order Items System** ✅ (Created locally)
   - Removed old `trg_do_inventory` trigger from `delivery_orders` table
   - Created `delivery_order_items` table for line items
   - Columns: do_id, internal_product_id, type_production_id, blending_id, truck_plate, weights, photo_url
   - Created `handle_do_inventory_detail()` trigger function for automatic inventory deduction
   - Trigger fires on INSERT to `delivery_order_items`

---

## Recent Database Changes (June 7, 2026)

### Schema Enhancements
1. **Delivery Orders System** ✅
   - Created `do_sequences` table for sequential SJ numbering per company
   - Enhanced `delivery_orders` table with new columns:
     - `company_id` (FK to master_companies)
     - `shipment_id` (FK to shipments)
     - `sj_number` (Surat Jalan number)
     - `date_of_issue`, `vessel_name`
     - `gross_weight`, `tare_weight`
     - `gross_terima`, `tare_terima`, `net_terima` (hidden backend fields)
   - Created `generate_sj_number()` function for formatted SJ numbers
   - Created `handle_do_inventory()` function for auto SALES_OUT entries
   - Created `trg_do_inventory` trigger for automatic inventory deduction

---

## Previous Database Changes (June 5, 2026)

### Schema Enhancements
1. **Shipments Column Updates** ✅
   - Added `jenis_batu` column (High, Medium, Low) with CHECK constraint
   - Renamed columns for better clarity:
     - `reference_no` → `invoice_no`
     - `origin_location` → `asal_batu`
     - `draft_survey_qty` → `quantity`
   - Updated views to reflect new column names

2. **Inventory Ledger Multi-Company Support** ✅
   - Added `company_id` column to `inventory_ledger`
   - Foreign key references `master_companies(id)`

3. **Triggers & Functions** ✅
   - Updated `handle_new_tally_log()` to handle INSERT, UPDATE, DELETE
   - Removed automatic `handle_shipment_completed()` trigger
   - Created `complete_shipment(p_shipment_id uuid)` RPC function for manual completion

4. **Updated Views** ✅
   - `view_shipments_detailed` - includes `invoice_no`, `asal_batu`, `quantity`, `company_name`
   - `view_shipment_summary` - uses `invoice_no` and `quantity`
   - `view_trucking_summary` - references `invoice_no`

## Previous Database Changes (June 4, 2026)

### Schema Enhancements
1. **Multi-Company Support** ✅
   - Added `master_companies` table with company_id, name, tax_id, logo_url
   - Added `company_id` foreign key to `master_warehouse`
   - Added `company_id` foreign key to `user_profiles`
   - Created indexes: `idx_warehouse_company`, `idx_user_company`

2. **Company Logo Management** ✅
   - Added `logo_url` column to `master_companies`
   - Created `company-logos` storage bucket
   - Configured RLS policies for public read/authenticated upload

3. **New Master Tables** ✅ (June 4, 2026)
   - Added `master_blending` table (nama_blending, cost)
   - Added `master_type_production` table (nama_type, cost)
   - Both tables have RLS with global access for authenticated users

4. **Shipments Table Enhancement** ✅ (June 4, 2026)
   - Added `company_id` for multi-tenant isolation
   - Added financial columns: `harga`, `ppn_tax`, `pph_tax`, `disc`
   - Added date tracking: `issue_date`, `loading_date`
   - Added `qty_loading` (auto-updated by system)
   - Added `is_completed` boolean flag
   - RLS policy: Company isolation

5. **Updated Views** ✅ (June 4, 2026)
   - `view_shipments_detailed` now includes `company_name`
   - `view_shipment_summary` with variance calculation: `((actual - expected) / expected) * 100`

---

## Recent App Fixes & Updates (June 2026)

1. **Security & Password Management ("Ganti Password")**
   - Implemented "show password" checkboxes for "Password Baru" and "Konfirmasi Password Baru" inputs on `/settings`.
   - Added clear UI/UX feedback messages indicating the success or failure of password update requests.

2. **Company Logo Upload Verification**
   - Debugged and resolved errors encountered during logo uploads on `/master/companies` (e.g. `MasterCompanies.tsx`). Fixed paths and database integrations.

3. **OCR Ticket Parser Endpoint Fix**
   - Resolved the error `OCR Server Error: OpenRouter Error: No endpoints found for google/gemini-2.0-flash-001`.
   - Updated the OpenRouter API payload in `ocr-ticket` Edge Function to target the active stable `google/gemini-2.5-flash` model.
   - Added deployment notes for Cloud/Staging: `npx supabase functions deploy ocr-ticket`.

4. **UI Label Localization Consistency**
   - Unified naming across the application in Indonesian.
   - Renamed menu item `'Input Tally'` in [src/locales/id.ts](file:///d:/BEN/NSM/frontend/src/locales/id.ts) and the page title `'Tally / Input'` in [src/pages/logistics/TallyInput.tsx](file:///d:/BEN/NSM/frontend/src/pages/logistics/TallyInput.tsx) to **"Input Masuk Barang"** for local clarity.

---

## Development Workflow

### Local Development Commands

```bash
# Start Supabase locally (excluding analytics on Windows)
npx supabase start

# Stop Supabase
npx supabase stop

# Generate migration after Studio changes (PRESERVES DATA)
npx supabase db diff -f <descriptive_name>

# Push database schema to cloud
npx supabase link --project-ref <your-ref>
npx supabase db push

# Deploy Edge Function to cloud
npx supabase functions deploy

# Set cloud secrets
npx supabase secrets set OPENROUTER_API_KEY=your_key
```

### Important: Workflow Notes

**⚠️ DO NOT use `db reset` during active development**
- `db reset` destroys and recreates the database, wiping all data
- Use `db diff` to generate migrations only
- Migrations are applied automatically when pushing to cloud

### Local URLs
| Service | URL |
|---------|-----|
| Supabase Studio | http://127.0.0.1:54911 |
| API Endpoint | http://127.0.0.1:54910 |
| Mailpit (Email Testing) | http://127.0.0.1:54912 |

### Cloud Deployment
| Property | Value |
|----------|-------|
| Project Ref | `ufazhiohzejkrgzioupn` |
| Dashboard | https://supabase.com/dashboard/project/ufazhiohzejkrgzioupn |
| Status | Linked and migrations pushed ✅ |

---

## Security Best Practices

### ✅ DO:
- Commit schema migrations (`supabase/migrations/*.sql`)
- Commit edge functions (`supabase/functions/`)
- Commit config files (`supabase/config.toml`)

### ❌ DO NOT:
- Make changes directly in Cloud Dashboard
- Commit `.env` files or API keys
- Commit SQL data dumps (`*.sql` in root)
- Commit markdown files with credentials
- Push `docs/` directory with sensitive data

### Golden Rule
**NEVER** make changes directly in the Cloud Dashboard. Always:
1. Make changes in Local Studio
2. Generate migration with `db diff`
3. Push to cloud with `db push`

---

## Current Database State (as of June 2026)

### Seed Data Loaded
- **8 user roles** configured
- **3 master partners** (Test Supplier 1, Test Customer 1, Test Transporter 1)
- **4 products** (HBA 1, HBA II, NSM-01, NSM-02)
- **2 shipments** (TEST SHIPMENT 1 & 2)
- **2 trucking logs** with inventory ledger entries
- **1 demo user** (demo@nsm.com - Manager role)

---

## Git History

### Latest Commit
**`99c9a49`** - feat(db): add DO cancellation system with RLS, cross-company support, and report view enhancements

**July 12, 2026 Changes:**
- Add po_number column to sales_orders
- Rename do_cancellation_requests columns (remove 'new_' prefix)
- Update approve_do_cancellation() function with Indonesian values, cross-company logic, and RETURN_ALL handling
- Add RLS policies for do_cancellation_requests and sales_orders
- Add is_cancel column to delivery_orders
- Update report views with created_by_name and additional columns
- **All 7 migrations pushed to cloud (ufazhiohzejkrgzioupn)** ✅

**July 12, 2026 Changes:**
- Add po_number column to sales_orders
- Rename do_cancellation_requests columns (remove 'new_' prefix)
- Update approve_do_cancellation() function with Indonesian values, cross-company logic, and RETURN_ALL handling
- Add RLS policies for do_cancellation_requests and sales_orders
- Add is_cancel column to delivery_orders
- Update report views with created_by_name and additional columns
- Add status column to tcp_input with CHECK constraint (ON_REQUEST/APPROVED/REJECTED)
- Create sync_tcp_status() function to sync status between tables
- Create trg_sync_tcp_status trigger on inventory_adjustments UPDATE
- Push 5 migrations to cloud (ufazhiohzejkrgzioupn)

### Previous Commit
**`65b673f`** - feat(backend): add delivery orders enhancements and inventory revert trigger

**Changes:**
- Add transporter_id (FK to master_partners) and adjust_weight columns to delivery_orders
- Add product_net, produk_net, and ticket_number columns to delivery_order_items
- Add hex_color column to master_companies for UI theming
- Create revert_inventory_on_delete() function to restore stock when delivery_order_items are deleted
- Create trg_revert_inventory_on_delete trigger on delivery_order_items
- Add idx_do_transporter index on delivery_orders(transporter_id)

### Earlier Commit
**`713f457`** - feat(backend): add delivery orders system and schema permissions

**Changes:**
- Add do_sequences table for sequential SJ numbering per company
- Add generate_sj_number() function for formatted 4-digit SJ numbers
- Add handle_do_inventory() function for automatic SALES_OUT inventory entries
- Enhance delivery_orders table with 10 new columns (company_id, shipment_id, sj_number, etc.)
- Add published_product_name column for product name snapshot
- Grant schema permissions to anon and authenticated roles
- Push 6 migrations to cloud (ufazhiohzejkrgzioupn)

**Changes:**
- Add master_companies table with logo support
- Add company_id foreign keys to warehouse and user profiles
- Create company-logos storage bucket with RLS policies
- Add 8 user roles with seed data
- Upgrade Supabase CLI to v2.102.0
- Add OCR ticket edge function
- Update .gitignore for security

### Migrations Created (June 10, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260610000000_add_sales_order_number_generator_function.sql` | Sales order number generator with yearly reset | ✅ Pushed |
| `20260610000001_add_delivery_order_items_table_and_trigger.sql` | DO line items table with inventory trigger | ✅ Pushed |

### Migrations Created & Pushed (June 16, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260616000000_add_delivery_orders_transporter_and_adjust_weight.sql` | transporter_id, adjust_weight + index on delivery_orders | ✅ Pushed |
| `20260616000001_add_revert_inventory_on_delete_function.sql` | Initial revert function (updated in next migration) | ✅ Pushed |
| `20260616000002_update_revert_inventory_function_and_add_trigger.sql` | Updated revert function + trigger on delivery_order_items | ✅ Pushed |
| `20260616000003_add_delivery_order_items_product_net_and_ticket.sql` | product_net, produk_net, ticket_number on delivery_order_items | ✅ Pushed |
| `20260616000004_add_master_companies_hex_color.sql` | hex_color on master_companies | ✅ Pushed |

### Migrations Created & Pushed (June 17, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260617000000_add_inventory_adjustments_table_and_function.sql` | inventory_adjustments table + approve function | ✅ Pushed |
| `20260617000001_enable_rls_on_delivery_order_items_and_do_sequences.sql` | RLS on delivery_order_items + do_sequences | ✅ Pushed |
| `20260617000002_add_inventory_adjustments_user_profiles_fk.sql` | FK constraints to user_profiles | ✅ Pushed |
| `20260617000003_add_tcp_input_table_and_shipments_fk.sql` | tcp_input table + shipments FK | ✅ Pushed |
| `20260617000004_add_rejection_notes_and_tcp_status_sync.sql` | rejection_notes + TCP status sync trigger | ✅ Pushed |

### Migrations Created & Pushed (June 8, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260607171457_update_sales_order_lock_function.sql` | Sales order lock function (Super User only can modify completed) | ✅ Pushed |
| `20260607173000_fix_delivery_orders_trigger_function.sql` | Fix handle_do_inventory to reference sales_orders not master_sales_order | ✅ Pushed |
| `20260607173530_add_delivery_orders_internal_product_id.sql` | Add internal_product_id column and update inventory trigger | ✅ Pushed |

### Migrations Created & Pushed (June 7, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260606054936_add_sales_order_company_id_and_lock_trigger.sql` | Sales order company_id and lock trigger | ✅ Pushed |
| `20260606060250_add_sales_order_product_name_and_auto_stock_out_trigger.sql` | Sales order product name and auto stock out trigger | ✅ Pushed |
| `20260607081532_add_delivery_orders_system.sql` | Created do_sequences table, generate_sj_number and handle_do_inventory functions, trg_do_inventory trigger | ✅ Pushed |
| `20260607081630_add_delivery_orders_columns.sql` | Added company_id, shipment_id, sj_number, weights, and hidden fields to delivery_orders | ✅ Pushed |
| `20260607155422_add_do_published_product_name.sql` | Added published_product_name column (snapshot) to delivery_orders | ✅ Pushed |
| `20260607155830_grant_public_schema_permissions.sql` | Granted USAGE and ALL privileges on public schema to anon/authenticated roles | ✅ Pushed |

### Migrations Created (June 6, 2026)
| Migration File | Description |
|----------------|-------------|
| `20260606033407_update_complete_shipment_function_duplicate_check.sql` | Added duplicate check prevention to complete_shipment RPC |
| `20260606033629_add_shipments_created_by_constraint_and_default.sql` | Added FK constraint for created_by and set default to auth.uid() |

### Migrations Created (June 5, 2026)
| Migration File | Description |
|----------------|-------------|
| `20260605023645_update_shipments_column_names.sql` | Column renames (invoice_no, asal_batu, quantity), add jenis_batu |
| `20260605031407_update_tally_trigger_function.sql` | Updated tally trigger for INSERT/UPDATE/DELETE |
| `20260605043657_add_shipment_completed_trigger.sql` | Initial shipment completion trigger |
| `20260605052403_update_shipment_completed_trigger_validation.sql` | Added company_id validation to trigger |
| `20260605054917_add_company_id_to_inventory_ledger.sql` | Added company_id FK to inventory_ledger |
| `20260605060917_update_shipment_trigger_full_validation.sql` | Full validation (product_id, quantity, company_id) |
| `20260605061335_replace_trigger_with_rpc_complete_shipment.sql` | Replaced trigger with RPC function |

### Migrations Created (June 4, 2026)
| Migration File | Description |
|----------------|-------------|
| `20260603045410_add_company_id_and_logo_url_columns.sql` | Company support for warehouse/users, RLS updates |
| `202606031222_create_blending_and_type_production_tables.sql` | New master tables for blending and production types |
| `202606031229_enhance_shipments_table.sql` | Financial tracking, dates, company isolation for shipments |
| `202606031235_update_shipment_views.sql` | Updated views with company_name and variance calculation |

---

## Environment Variables Required

Set in `.env` for local development or Supabase Secrets for production:
- `OPENROUTER_API_KEY` - For OCR ticket processing
- `SUPABASE_AUTH_EXTERNAL_*` - OAuth provider secrets (if needed)

---

## Troubleshooting

### Docker Network Issues
If you encounter `network supabase_network_backend not found`:
```bash
npx supabase stop
docker network prune -f
npx supabase start
```

### Analytics Container Issue (Windows)
The analytics container may fail to start on Windows. This is a known issue and doesn't affect core functionality. Start Supabase normally - analytics will be skipped automatically.

### Permission Denied Errors
If you get permission errors on role operations, reset the database:
```bash
npx supabase db reset
```
⚠️ **Warning**: This will wipe all local data

---

## Next Steps / TODO

### Completed ✅
- [x] Add company_id to master_partners and master_products (June 24, 2026)
- [x] Update RLS policies for company isolation (June 24, 2026)
- [x] Update inventory ledger triggers with new transaction types (June 24, 2026)
- [x] Add type_sj column to master_companies (June 24, 2026)
- [x] Generate comprehensive migration from Studio changes (June 24, 2026)
- [x] Create DO cancellation requests system (July 10, 2026)
- [x] Add DO cancellation approval trigger function (July 10, 2026)
- [x] Update DO cancellation FK to user_profiles (July 10, 2026)
- [x] Add company_id to do_cancellation_requests (July 10, 2026)
- [x] Add reason column to do_cancellation_requests (July 10, 2026)
- [x] Update request_type CHECK constraint to Indonesian values (July 10, 2026)
- [x] Update approve_do_cancellation() to Indonesian request_type values (July 12, 2026)
- [x] Add RLS policies for do_cancellation_requests (July 12, 2026)
- [x] Rename do_cancellation_requests columns (remove 'new_' prefix) (July 12, 2026)
- [x] Add cross-company Sales Order logic with SJ regeneration (July 12, 2026)
- [x] Add is_cancel column to delivery_orders (July 12, 2026)
- [x] Add RETURN_ALL inventory reversal logic (July 12, 2026)
- [x] Update report views with created_by_name (July 12, 2026)
- [x] Add po_number to sales_orders (July 12, 2026)
- [x] Backup local database (July 12, 2026)
- [x] Create migration for recent manual SQL changes (company_id, logo_url columns)
- [x] Add master_blending and master_type_production tables
- [x] Enhance shipments table with financial tracking
- [x] Update shipment views with company support
- [x] Set up cloud Supabase project link (ufazhiohzejkrgzioupn)
- [x] Push migrations to cloud
- [x] Deploy edge functions to cloud
- [x] Add shipments column updates (jenis_batu, renames)
- [x] Add company_id to inventory_ledger
- [x] Replace shipment completion trigger with RPC function
- [x] Update tally trigger for full CRUD support
- [x] Create delivery orders system with SJ numbering and auto-inventory deduction
- [x] Add published_product_name column to delivery_orders (snapshot)
- [x] Grant public schema permissions to anon/authenticated roles
- [x] Push 6 migrations to cloud (June 7, 2026)
- [x] Fix delivery orders trigger bug (master_sales_order → sales_orders)
- [x] Add internal_product_id column to delivery_orders
- [x] Add sales order completion lock (Super User only can modify)
- [x] Push 3 migrations to cloud (June 8, 2026)
- [x] Create sales order number generator function (yearly reset with month display)
- [x] Create delivery_order_items table with inventory trigger (June 10, 2026)
- [x] Create 2 migration files for new features (June 10, 2026)
- [x] Push new migrations to cloud (June 10, 2026 migrations)
- [x] Add transporter_id and adjust_weight to delivery_orders (June 16, 2026)
- [x] Add revert_inventory_on_delete function and trigger (June 16, 2026)
- [x] Add product_net, produk_net, ticket_number to delivery_order_items (June 16, 2026)
- [x] Add hex_color to master_companies (June 16, 2026)
- [x] Push 5 migrations to cloud (June 16, 2026)
- [x] Create inventory_adjustments table and approve_inventory_adjustment function (June 17, 2026)
- [x] Enable RLS on delivery_order_items and do_sequences (June 17, 2026)
- [x] Add FK constraints for inventory_adjustments to user_profiles (June 17, 2026)
- [x] Create tcp_input table and add id_tcp to shipments (June 17, 2026)
- [x] Add rejection_notes and status sync for TCP system (June 17, 2026)
- [x] Push 5 migrations to cloud (June 17, 2026)
- [x] Commit and push to GitHub (commit 89f1bfe) (June 17, 2026)

### Pending - Next Session
- [x] Commit and push 7 new migrations to GitHub and cloud (July 12, 2026 batch) ✅
- [ ] Update frontend to use DO cancellation request system
- [ ] Test cross-company Sales Order changes in production
- [ ] Test RETURN_ALL inventory reversal workflow
- [ ] Update frontend to use new delivery_orders columns (is_cancel, transporter_id, adjust_weight)
- [ ] Update frontend to utilize new transaction types (SALES_LOOSING, SALES_STOCK_PILE, PEMBELIAN)
- [ ] Update frontend to use new delivery_order_items structure (product_net, produk_net, ticket_number)
- [ ] Update frontend to use new delivery_orders columns (transporter_id, adjust_weight)
- [ ] Update frontend to use master_companies hex_color for theming
- [ ] Update frontend to use inventory_adjustments system for stock adjustment requests
- [ ] Update frontend to use tcp_input table for TCP tracking
- [ ] Test `approve_inventory_adjustment()` RPC function via Supabase Studio
- [ ] Test `sync_tcp_status()` trigger by updating inventory_adjustments status
- [ ] Test `revert_inventory_on_delete()` trigger by deleting a delivery_order_item
- [ ] Update frontend to call `get_next_so_number()` RPC for SO number generation
- [ ] Test `generate_sj_number()` RPC function via Supabase Studio
- [ ] Test `complete_shipment()` RPC function via Supabase Studio
- [ ] Update frontend to use new delivery_orders columns (sj_number, vessel_name, etc.)
- [ ] Update frontend to call `generate_sj_number()` RPC for DO creation
- [ ] Update frontend to use new column names (invoice_no, asal_batu, quantity)
- [ ] Update frontend to call `complete_shipment()` RPC
- [ ] Update Supabase CLI to v2.106.0

### Pending - Future
- [ ] Set OPENROUTER_API_KEY in Supabase Dashboard (requires manual setup or access token)
- [ ] Create seed.sql to preserve test data across resets
- [ ] Implement row-level security policies based on user roles
- [ ] Add API rate limiting for production
- [ ] Set up automated backups

---

## Project Links

- **GitHub**: https://github.com/borist-nababan-cloud/ctlms-supabase-backend
- **Documentation**: [CLAUDE.md](../CLAUDE.md)
- **Migration Files**: `supabase/migrations/`
- **Edge Functions**: `supabase/functions/`

---

## Session Summary: June 5, 2026

### Actions Taken
1. **Environment Setup**
   - Restarted Supabase local development environment
   - Updated Supabase CLI from v2.102.0 to v2.105.0

2. **Database Schema Changes**
   - Added `jenis_batu` column to shipments (High/Medium/Low)
   - Renamed columns: `reference_no` → `invoice_no`, `origin_location` → `asal_batu`, `draft_survey_qty` → `quantity`
   - Added `company_id` to `inventory_ledger` with FK constraint

3. **Trigger & Function Updates**
   - Updated `handle_new_tally_log()` to handle INSERT, UPDATE, DELETE operations
   - Removed automatic `handle_shipment_completed()` trigger
   - Created `complete_shipment(p_shipment_id)` RPC function for manual shipment completion

4. **Migration Files Created** (7 total)
   - All migrations preserve existing data (using RENAME COLUMN not DROP+ADD)
   - Ready to push to cloud

### Key Design Decisions
- **Manual vs Automatic**: Changed from automatic trigger to RPC function for shipment completion
- **Data Preservation**: Used `ALTER TABLE ... RENAME COLUMN` to preserve existing data
- **Validation**: Added comprehensive validation before inventory ledger entries

---

## Session Summary: June 6, 2026

### Actions Taken
1. **Environment Status**
   - Confirmed Supabase local development environment was already running
   - Identified CLI version discrepancy: v2.102.0 installed (v2.105.0 available)

2. **RPC Function Enhancement**
   - Updated `complete_shipment()` function with duplicate check logic
   - Added `IF NOT EXISTS` check before inserting into `inventory_ledger`
   - Changed return message to Indonesian: "Pengiriman selesai dan stok berhasil ditambah"
   - Created migration: `20260606033407_update_complete_shipment_function_duplicate_check.sql`

3. **Shipment Table Enhancement**
   - Added foreign key constraint: `shipments_created_by_fkey` referencing `auth.users(id)` with `ON DELETE SET NULL`
   - Set default value for `created_by` column to `auth.uid()`
   - Frontend no longer needs to send `created_by` explicitly
   - Created migration: `20260606033629_add_shipments_created_by_constraint_and_default.sql`

### Key Design Decisions
- **Duplicate Prevention**: RPC function now checks for existing ledger entries before inserting
- **Auto-Population**: `created_by` automatically captures the authenticated user on insert
- **Cascade Behavior**: User deletion sets `created_by` to NULL instead of blocking deletion

---

## Session Summary: June 7, 2026

### Actions Taken
1. **Environment Setup**
   - Started Supabase local development environment
   - Stopped Supabase after completing work

2. **Delivery Orders System Implementation**
   - Created `do_sequences` table for managing sequential SJ (Surat Jalan) numbers per company
   - Enhanced `delivery_orders` table with 9 new columns:
     - `company_id` - Foreign key to master_companies
     - `shipment_id` - Foreign key to shipments (links to vessel/barge)
     - `sj_number` - Sequential Surat Jalan number
     - `date_of_issue` - Issue date (defaults to CURRENT_DATE)
     - `vessel_name` - Vessel/barge name
     - `gross_weight`, `tare_weight` - Weighbridge weights
     - `gross_terima`, `tare_terima`, `net_terima` - Hidden backend fields for received weights
   - Created `generate_sj_number(p_company_id uuid)` function with row-level locking
   - Created `handle_do_inventory()` function for automatic SALES_OUT ledger entries
   - Created `trg_do_inventory` trigger to auto-deduct inventory on DO creation

3. **Migration Files Created** (2 total)
   - Both migrations preserve existing data using `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`

### Key Design Decisions
- **Sequential Numbering**: Centralized sequence table with row locking prevents duplicate SJ numbers
- **Auto-Inventory**: Automatic SALES_OUT entries on delivery order creation reduces manual data entry
- **Company Isolation**: SJ sequences are per-company, allowing separate numbering per tenant

---

## Session Summary: June 7, 2026 (Continued)

### Actions Taken
1. **Environment Management**
   - Started and stopped Supabase local development environment multiple times
   - Restarted PostgREST (API Service) by restarting Supabase

2. **Additional Database Schema Enhancements**
   - Added `published_product_name` column to `delivery_orders` table
     - Purpose: Snapshot of product name at time of delivery (preserves historical data if master product name changes)
   - Granted schema permissions:
     - `GRANT USAGE ON SCHEMA public TO anon, authenticated`
     - `GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated`

3. **Git & Cloud Deployment**
   - Created comprehensive commit message for 6 migration files
   - Committed with message: "feat(backend): add delivery orders system and schema permissions"
   - Pushed commit `713f457` to GitHub repository
   - Linked Supabase to cloud project `ufazhiohzejkrgzioupn`
   - Successfully pushed all 6 migrations to cloud database

4. **Documentation Updates**
   - Updated `docs/PROJECT_SUMMARY.md` with latest session details
   - Marked cloud migration push as completed

### Key Design Decisions
- **Product Name Snapshot**: `published_product_name` preserves historical data even if master product names change
- **Schema Permissions**: Granted broad access to anon/authenticated for easier frontend integration (RLS still applies for data-level security)

---

## Session Summary: June 8, 2026

### Actions Taken
1. **Environment Management**
   - Ran `supabase db push` to sync cloud database

2. **Bug Fix - Critical Production Issue**
   - **Problem**: Live application returning 404 error: `relation "public.master_sales_order" does not exist`
   - **Root Cause**: Cloud database had stale `handle_do_inventory()` function referencing wrong table name
   - **Solution**: Created and pushed migration to fix function reference from `master_sales_order` to `sales_orders`
   - **Result**: Delivery orders now working correctly in production

3. **Database Schema Enhancements**
   - Added `internal_product_id` column to `delivery_orders` table (FK to `master_products`)
   - Updated `handle_do_inventory()` function:
     - Now uses `internal_product_id` directly instead of indirect lookup via sales order
     - Added validation: raises exception if `internal_product_id` is NULL
     - Error message: "Internal Product ID tidak boleh kosong untuk pengiriman!"
   - Updated `check_sales_order_lock()` function to prevent modification of completed sales orders
   - Only Super User (user_role = 8) can modify completed sales orders

4. **Git & Cloud Deployment**
   - Created commit message: "fix(backend): fix delivery orders trigger and add internal_product_id"
   - Committed and pushed commit `690b8e9` to GitHub repository
   - Successfully pushed 3 migrations to cloud database

5. **Documentation Updates**
   - Updated `docs/PROJECT_SUMMARY.md` with June 8 session details

### Key Design Decisions
- **Direct Product Reference**: Changed from indirect lookup (via sales order) to direct `internal_product_id` for more explicit inventory tracking
- **Data Integrity**: Required `internal_product_id` field prevents delivery orders without proper product association
- **Security**: Sales order completion lock prevents accidental modification of finalized transactions

### Lessons Learned
- **Cloud-Local Drift**: Cloud database can have stale function definitions even when local is correct
- **Testing Gap**: Need to test cloud changes after migration pushes, not just local testing

---

## Session Summary: June 10, 2026

### Actions Taken
1. **Environment Management**
   - Started Supabase local development environment
   - Stopped Supabase after completing work

2. **Sales Order Number Generator Function**
   - Created `get_next_so_number()` function for auto-generating sequential SO numbers
   - Format: `SO/YYMM/XXXXX` (e.g., `SO/2606/00001`)
   - **Sequence resets yearly**, not monthly
   - The month (`MM`) is displayed in the number for clarity
   - Sequence (`XXXXX`) continues across months within the same year
   - Example behavior:
     - January 2026: `SO/2601/00001`, `SO/2601/00002`
     - February 2026: `SO/2602/00003` (continues from Jan's sequence)
     - January 2027: `SO/2701/00001` (new year, sequence resets)

3. **Delivery Order Items System**
   - Removed old trigger `trg_do_inventory` from `delivery_orders` table
   - Removed old function `handle_do_inventory()`
   - Created new `delivery_order_items` table for line items with columns:
     - `do_id` (FK to delivery_orders with CASCADE delete)
     - `internal_product_id` (FK to master_products)
     - `type_production_id` (FK to master_type_production)
     - `blending_id` (FK to master_blending)
     - `truck_plate`, `gross_weight`, `tare_weight`, `net_weight`, `photo_url`
   - Created new `handle_do_inventory_detail()` trigger function
   - Trigger fires on INSERT to `delivery_order_items`
   - Automatically deducts inventory with `SALES_OUT` transaction
   - Gets `company_id` from parent `delivery_orders` header

4. **Migration Files Created** (2 total)
   - `20260610000000_add_sales_order_number_generator_function.sql`
   - `20260610000001_add_delivery_order_items_table_and_trigger.sql`

### Key Design Decisions
- **Yearly Reset with Month Display**: SO numbers show month for clarity but sequence resets yearly, making it easier to track annual volumes
- **Line Item Architecture**: Moved inventory deduction to delivery_order_items for more granular tracking per truck/item
- **CASCADE Delete**: delivery_order_items are automatically removed when parent DO is deleted

### Migration Files Created (June 10, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260610000000_add_sales_order_number_generator_function.sql` | Sales order number generator with yearly reset | ✅ Created (local) |
| `20260610000001_add_delivery_order_items_table_and_trigger.sql` | DO line items table with inventory trigger | ✅ Created (local) |

---

## Session Summary: June 16, 2026

### Actions Taken
1. **Environment Management**
   - Confirmed Supabase local development environment was already running

2. **Delivery Orders Schema Enhancements**
   - Added `transporter_id` column to `delivery_orders` table (FK to `master_partners`)
   - Added `adjust_weight` column to `delivery_orders` table (numeric, defaults to 0)
   - Created index `idx_do_transporter` on `delivery_orders(transporter_id)` for search optimization
   - Migration: `20260616000000_add_delivery_orders_transporter_and_adjust_weight.sql`

3. **Inventory Reversal System for Delivery Order Items**
   - Created `revert_inventory_on_delete()` function to restore stock when `delivery_order_items` are deleted
   - Function uses `DECLARE v_company_id` variable for proper company_id lookup from parent `delivery_orders`
   - Uses `produk_net` column for reversal quantity
   - Transaction type: `ADJUSTMENT` with notes 'REVERSAL: Deleted Item Truck {plate}'
   - Created trigger `trg_revert_inventory_on_delete` on `delivery_order_items` (AFTER DELETE)
   - Migrations:
     - `20260616000001_add_revert_inventory_on_delete_function.sql` (initial version)
     - `20260616000002_update_revert_inventory_function_and_add_trigger.sql` (updated version with trigger)

4. **Delivery Order Items Schema Enhancements**
   - Added `product_net` column to `delivery_order_items` table (numeric, default '0')
   - Added `produk_net` column to `delivery_order_items` table (numeric, default 0)
   - Added `ticket_number` column to `delivery_order_items` table (text)
   - Migration: `20260616000003_add_delivery_order_items_product_net_and_ticket.sql`

5. **Master Companies Enhancement**
   - Added `hex_color` column to `master_companies` table (text)
   - Purpose: UI theming support for company-specific colors
   - Migration: `20260616000004_add_master_companies_hex_color.sql`

6. **Git & Cloud Deployment**
   - Created commit message: "feat(backend): add delivery orders enhancements and inventory revert trigger"
   - Committed and pushed commit `65b673f` to GitHub repository
   - Successfully pushed 5 migrations to cloud database

### Key Design Decisions
- **Inventory Reversal on Delete**: Automatic stock restoration when delivery order items are deleted prevents orphaned inventory deductions
- **Company Isolation in Reversal**: Reversal function fetches `company_id` from parent `delivery_orders` to maintain proper multi-tenant isolation
- **Transporter Tracking**: Added `transporter_id` to `delivery_orders` for better logistics tracking and reporting
- **Color Theming**: Added `hex_color` to `master_companies` for frontend UI customization per company
- **Performance**: Index on `transporter_id` optimizes queries filtering by transporter

### Migration Files Created (June 16, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260616000000_add_delivery_orders_transporter_and_adjust_weight.sql` | transporter_id, adjust_weight + index on delivery_orders | ✅ Pushed |
| `20260616000001_add_revert_inventory_on_delete_function.sql` | Initial revert function (updated in next migration) | ✅ Pushed |
| `20260616000002_update_revert_inventory_function_and_add_trigger.sql` | Updated revert function + trigger on delivery_order_items | ✅ Pushed |
| `20260616000003_add_delivery_order_items_product_net_and_ticket.sql` | product_net, produk_net, ticket_number on delivery_order_items | ✅ Pushed |
| `20260616000004_add_master_companies_hex_color.sql` | hex_color on master_companies | ✅ Pushed |

---

## Session Summary: June 17, 2026

### Actions Taken
1. **Environment Management**
   - Started Supabase local development environment
   - Ran multiple `supabase db diff` commands to check for schema changes

2. **Inventory Adjustment Request System**
   - Created `inventory_adjustments` table for managing stock adjustment requests
   - Columns: id, company_id, product_id, current_stock_snapshot, actual_stock, status (ON_REQUEST/APPROVED/REJECTED), notes, created_by, approved_by, created_at, rejection_notes
   - Created `approve_inventory_adjustment(p_adjustment_id uuid)` function for executing approval workflow
   - Function calculates delta (actual - snapshot) and inserts ADJUSTMENT entry to `inventory_ledger`
   - Migration: `20260617000000_add_inventory_adjustments_table_and_function.sql`

3. **RLS Policy Updates**
   - Enabled RLS on `delivery_order_items` table
   - Enabled RLS on `do_sequences` table
   - Created policies allowing authenticated users full access (SELECT, INSERT, UPDATE, DELETE)
   - Migration: `20260617000001_enable_rls_on_delivery_order_items_and_do_sequences.sql`

4. **Foreign Key Constraints Enhancement**
   - Added FK constraint: `inventory_adjustments_created_by_user_profiles_fkey` referencing `user_profiles(uuid)` with `ON DELETE SET NULL`
   - Added FK constraint: `inventory_adjustments_approved_by_user_profiles_fkey` referencing `user_profiles(uuid)` with `ON DELETE SET NULL`
   - Purpose: Allow PostgREST to automatically resolve joins between tables
   - Migration: `20260617000002_add_inventory_adjustments_user_profiles_fk.sql`

5. **TCP Input System**
   - Created `tcp_input` table for tracking TCP (Total Coal Production) values
   - Columns: id, shipment_id (FK to shipments), product_id (FK to master_products), tcp_value, total_in, total_out, actual_stock, current_stock_snapshot, inventory_adjustment_id (FK to inventory_adjustments), notes, created_at, company_id (FK to master_companies), status, rejection_notes
   - Added `id_tcp` column to `shipments` table (1:1 relationship)
   - Enabled RLS with full access policy for authenticated users
   - Migration: `20260617000003_add_tcp_input_table_and_shipments_fk.sql`

6. **TCP Status Sync Enhancement** (Studio Modifications)
   - Added `rejection_notes` column to `inventory_adjustments` table
   - Added `rejection_notes` column to `tcp_input` table
   - Added `status` column to `tcp_input` with CHECK constraint (ON_REQUEST, APPROVED, REJECTED)
   - Created `sync_tcp_status()` function to sync status from `inventory_adjustments` to `tcp_input`
   - Created trigger `trg_sync_tcp_status` on `inventory_adjustments` UPDATE
   - Trigger fires when status or rejection_notes changes
   - Migration: `20260617000004_add_rejection_notes_and_tcp_status_sync.sql`

7. **Git & Cloud Deployment**
   - Created commit message: "feat(backend): add tcp_input table and inventory adjustment enhancements"
   - Committed and pushed commit `89f1bfe` to GitHub repository
   - Successfully pushed 5 migrations to cloud database
   - Verified `.gitignore` excludes sensitive data (docs/, my-cred/, database-docs/, *.md, *.sql, .env files)

### Key Design Decisions
- **Approval Workflow**: Inventory adjustments require explicit approval via RPC function, preventing unauthorized stock modifications
- **Stock Snapshot**: Captures current stock at request creation time for comparison with actual physical stock
- **Delta Calculation**: Automatic calculation of difference (actual - snapshot) for ledger entries
- **Multi-Table Sync**: TCP input status automatically syncs with parent inventory adjustment status via trigger
- **Rejection Tracking**: Added rejection_notes to both tables for audit trail
- **Status Management**: TCP status follows same workflow as inventory adjustments (ON_REQUEST → APPROVED/REJECTED)
- **RLS by Default**: All new tables have RLS enabled with authenticated user access
- **1:1 Shipment-TCP Relationship**: Each shipment can have one TCP input record via id_tcp foreign key

### Migration Files Created (June 17, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260617000000_add_inventory_adjustments_table_and_function.sql` | inventory_adjustments table + approve function | ✅ Pushed |
| `20260617000001_enable_rls_on_delivery_order_items_and_do_sequences.sql` | RLS on delivery_order_items + do_sequences | ✅ Pushed |
| `20260617000002_add_inventory_adjustments_user_profiles_fk.sql` | FK constraints to user_profiles | ✅ Pushed |
| `20260617000003_add_tcp_input_table_and_shipments_fk.sql` | tcp_input table + shipments FK | ✅ Pushed |
| `20260617000004_add_rejection_notes_and_tcp_status_sync.sql` | rejection_notes + TCP status sync trigger | ✅ Pushed |

---

## Session Summary: June 24, 2026

### Actions Taken
1. **Environment Management**
   - Started Supabase local development environment successfully
   - All services running correctly:
     - Studio: http://127.0.0.1:54911
     - API: http://127.0.0.1:54910
     - Database: postgresql://postgres:postgres@127.0.0.1:54900/postgres
     - Mailpit: http://127.0.0.1:54912

2. **Multi-Tenancy Architecture Enhancement**
   - Added `company_id` field to `master_partners` table (nullable, FK to `master_companies`)
   - Added `company_id` field to `master_products` table (nullable, FK to `master_companies`)
   - Purpose: Enable company-based data isolation while allowing global data (NULL = visible to all)
   - Migrations:
     - `20260624001619_add_company_id_to_master_partners.sql`
     - `20260624005157_add_company_id_to_master_products.sql`

3. **Row Level Security (RLS) Policies**
   - Created company isolation policies for `master_partners` table
   - Updated `master_products` policies: removed company isolation, added full authenticated access
   - Migration: `20260624005949_update_company_id_policies.sql`

4. **Inventory Ledger System Enhancements**
   - Updated `handle_shipment_completed()` function to use `TALLY_IN` transaction type
   - Updated `handle_do_inventory_detail()` function with improved logic:
     - Determines transaction type based on delivery_type:
       - `DIRECT` → `SALES_LOOSING`
       - `STOCKPILE` → `SALES_STOCK_PILE`
     - Added DELETE operation handling
     - Uses ON CONFLICT for UPSERT behavior
   - Updated `handle_adjustment_ledger()` function:
     - Only triggers when status changes TO 'APPROVED'
     - Uses `company_id` from adjustment table directly
   - Migration: `20260624115428_update_inventory_ledger_triggers.sql`

5. **User Modifications via Studio GUI**
   - Updated `handle_do_inventory_detail()` function (user modified trigger)
   - Updated `handle_shipment_completed()` function to use `PEMBELIAN` transaction type
   - Added `type_sj` column to `master_companies` (smallint, default: 1)
   - Updated `inventory_ledger` transaction type CHECK constraint to include:
     - `TALLY_IN`, `SALES_OUT`, `ADJUSTMENT`, `PEMBELIAN`, `SALES_STOCK_PILE`, `TCP_INPUT`, `RETURN`, `SALES_LOOSING`
   - Created `on_shipment_completed` trigger on shipments table

6. **Comprehensive Migration Generated**
   - Generated migration from Studio changes: `20260624065119_comprehensive_updates.sql`
   - Contains all trigger updates, new columns, and constraint changes

7. **Data Management**
   - Accidentally pulled remote data to local (too many records for testing)
   - User requested `db reset` to start fresh with clean local database
   - Successfully reset local database with all migrations applied

### Key Design Decisions
- **Multi-Tenancy Ready**: Company ID fields enable future data isolation while maintaining backward compatibility
- **Flexible Transaction Types**: Expanded inventory ledger to support more granular transaction tracking
- **Auto-Inventory Logic**: Triggers automatically determine correct transaction type based on delivery context
- **SJ Numbering Type**: Added `type_sj` to `master_companies` for configurable invoice numbering per company

### Inventory Transaction Types (Updated)
| Transaction Type | Description | Trigger Source |
|------------------|-------------|----------------|
| `TALLY_IN` | Incoming coal from tally/shipping | `handle_shipment_completed()` |
| `PEMBELIAN` | Purchase/procurement | `handle_shipment_completed()` |
| `SALES_LOOSING` | Direct barge sales (loosing) | `handle_do_inventory_detail()` |
| `SALES_STOCK_PILE` | Stockpile sales | `handle_do_inventory_detail()` |
| `SALES_OUT` | General sales outflow | Various |
| `ADJUSTMENT` | Manual stock adjustments | `handle_adjustment_ledger()` |
| `TCP_INPUT` | TCP input transactions | TCP system |
| `RETURN` | Returned goods | Return handling |

### Migration Files Created & Pushed (June 24, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260624001619_add_company_id_to_master_partners.sql` | company_id to master_partners | ✅ Pushed |
| `20260624005157_add_company_id_to_master_products.sql` | company_id to master_products | ✅ Pushed |
| `20260624005949_update_company_id_policies.sql` | Company isolation RLS policies | ✅ Pushed |
| `20260624115428_update_inventory_ledger_triggers.sql` | Updated inventory ledger triggers | ✅ Pushed |
| `20260624065119_comprehensive_updates.sql` | Studio GUI changes (user modifications) | ✅ Pushed |

### Pending Tasks
- [x] Review and verify comprehensive migration before pushing to cloud
- [x] Push all 5 new migrations to cloud database (June 26, 2026)
- [ ] Update frontend to utilize new transaction types
- [ ] Create seed data for local testing

---

## Session Summary: June 26, 2026

### Actions Taken
1. **Environment Management**
   - Started Supabase local development environment
   - All services running correctly on ports 54900-54912

2. **Database Backup**
   - Created full data backup of local database
   - Backup file: `docs/sql_backup/backup.sql`
   - Size: 188 KB
   - Format: Data-only SQL dump with column inserts

3. **Schema Verification & Cloud Push**
   - Ran `supabase db diff` to verify no pending local changes
   - Found 5 migrations from June 24, 2026 awaiting cloud deployment
   - Successfully pushed all 5 migrations to cloud database (ufazhiohzejkrgzioupn)
   - Migrations applied:
     - company_id to master_partners and master_products
     - Company isolation RLS policies
     - Comprehensive updates (Studio GUI changes)
     - Updated inventory ledger triggers

4. **Studio SQL Editor Changes**
   - Generated migration from Studio SQL changes: `20260626091145_studio_changes.sql`
   - Updated `view_inventory_current` to group by company_id
   - Created `view_delivery_report` for comprehensive delivery reporting with customer/supplier context
   - Created `view_ledger_details` for inventory ledger with supplier/vessel information
   - Updated `handle_do_inventory_detail()` trigger to use:
     - `SALES_LOOSING` for DIRECT delivery type
     - `SALES_STOCK_PILE` for other delivery types
   - Updated `handle_shipment_completed()` trigger to use `PEMBELIAN` transaction type
   - Successfully pushed migration to cloud database
   - Committed and pushed to GitHub (commit `30c5597`)

### Key Design Decisions
- **Backup Strategy**: Regular backups ensure data safety during development cycles
- **Migration Workflow**: Local changes → db diff → review → db push to cloud maintains consistency
- **Transaction Type Granularity**: Different sales transaction types (LOOSING vs STOCK_PILE) enable better inventory tracking
- **Multi-Tenant Inventory**: Inventory views now group by company_id for proper isolation

### Migration Files Pushed (June 26, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260624001619_add_company_id_to_master_partners.sql` | company_id to master_partners | ✅ Pushed |
| `20260624005157_add_company_id_to_master_products.sql` | company_id to master_products | ✅ Pushed |
| `20260624005949_update_company_id_policies.sql` | Company isolation RLS policies | ✅ Pushed |
| `20260624115428_update_inventory_ledger_triggers.sql` | Updated inventory ledger triggers | ✅ Pushed |
| `20260624065119_comprehensive_updates.sql` | Studio GUI changes (user modifications) | ✅ Pushed |
| `20260626091145_studio_changes.sql` | Inventory views and trigger updates | ✅ Pushed |

---

## Session Summary: June 29, 2026

### Actions Taken
1. **Studio SQL Editor Changes**
   - Generated migration from Studio SQL changes: `20260629092528_studio_sql_changes.sql`
   - Enhanced `inventory_adjustments` table:
     - Added `selisih` column (numeric, default 0)
     - Added `shipment_id` column with foreign key to shipments
   - Enhanced `tcp_input` table:
     - Added `created_by` column with foreign key to auth.users
   - Created `view_adjustment_report` for comprehensive inventory adjustments reporting
   - Created `view_tcp_report` for TCP input analysis with shipment context
   - Enhanced `view_ledger_details` to show:
     - `sj_number` and `customer_name` for sales transactions
     - Conditional joins based on transaction_type (PEMBELIAN vs SALES_LOOSING/SALES_STOCK_PILE)
   - Successfully pushed migration to cloud database
   - Committed and pushed to GitHub (commit `e4dac87`)

### Key Design Decisions
- **Enhanced Reporting Views**: New views provide comprehensive reporting for adjustments and TCP analysis
- **Supplier Linkage**: `shipment_id` in inventory_adjustments enables direct reference to procurement source
- **Audit Trail**: `created_by` in tcp_input improves accountability for TCP input records
- **Conditional Ledger Display**: view_ledger_details adapts join logic based on transaction type for accurate context

### Migration Files Pushed (June 29, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260629092528_studio_sql_changes.sql` | Adjustment/TCP enhancements and reporting views | ✅ Pushed |

---

### Migrations Created (July 12, 2026) - Not Yet Pushed
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260712025751_add_po_number_to_sales_orders.sql` | PO number column to sales_orders + view update | ✅ Created (local) |
| `20260712041104_rename_do_cancellation_columns_and_update_function.sql` | Column renames + approve_do_cancellation updates | ✅ Created (local) |
| `20260712045220_add_rls_policies_for_do_cancellation_and_sales_orders.sql` | RLS policies for DO cancellation + sales orders | ✅ Created (local) |
| `20260712060049_update_approve_do_cancellation_with_cross_company_logic.sql` | Cross-company SO logic with SJ regeneration | ✅ Created (local) |
| `20260712065726_add_is_cancel_to_delivery_orders_and_update_cancellation_function.sql` | is_cancel column + RETURN_ALL handling | ✅ Created (local) |
| `20260712071754_update_view_delivery_report_with_is_cancel_column.sql` | View updates with cancel flag + transporter info | ✅ Created (local) |
| `20260712074542_update_multiple_reports_views_with_created_by_name.sql` | Added created_by_name to report views | ✅ Created (local) |

---

## Session Summary: July 10, 2026

### Actions Taken
1. **Environment Management**
   - Started Supabase local development environment successfully
   - All services running correctly on ports 54900-54912

2. **DO Cancellation Requests System Implementation**
   - Created `do_cancellation_requests` table for managing delivery order cancellation/modification requests
   - Table columns: id, do_id, request_type, new_truck_plate, new_transporter_id, new_sales_order_id, return_product_id, notes, status, created_by, approved_by, created_at, company_id, reason
   - Request types (Indonesian): 'Ganti Kendaraan', 'Ganti Sales Order', 'Pengembalian Stok (Per Item)', 'Pengembalian Stok (Total)'
   - Status workflow: ON_REQUEST → APPROVED/REJECTED
   - Migration: `20260710032924_add_do_cancellation_requests_table_and_trigger.sql`

3. **DO Cancellation Approval Trigger**
   - Created `approve_do_cancellation()` function for automatic execution when status changes to APPROVED
   - Function handles 3 request types:
     - **Ganti Kendaraan**: Updates truck_plate and transporter_id in delivery_orders
     - **Ganti Sales Order**: Updates sales_order_id in delivery_orders
     - **Pengembalian Stok (Total)**: Inserts RETURN entry to inventory_ledger for all items
   - Created `trg_approve_do_cancellation` trigger (AFTER UPDATE)
   - **Note**: Trigger function needs update to use Indonesian request_type values

4. **Foreign Key Updates**
   - Changed `created_by` FK from `auth.users(id)` to `user_profiles(uuid)` with ON DELETE SET NULL
   - Changed `approved_by` FK from `auth.users(id)` to `user_profiles(uuid)` with ON DELETE SET NULL
   - Migration: `20260710040026_update_do_cancellation_user_profiles_fk.sql`

5. **Company Isolation Enhancement**
   - Added `company_id` column to `do_cancellation_requests` table
   - Added FK constraint to `master_companies(id)` with ON DELETE CASCADE
   - Migration: `20260710040557_add_do_cancellation_company_id.sql`

6. **Reason Column Addition**
   - Added `reason` column (text) for cancellation reason tracking
   - Migration: `20260710043728_add_do_cancellation_reason_column.sql`

7. **Request Type Constraint Update**
   - Dropped old CHECK constraint with English values (CHANGE_TRUCK, CHANGE_SO, RETURN_ITEM, RETURN_ALL)
   - Added new CHECK constraint with Indonesian values matching frontend
   - Migration: `20260710050032_update_do_cancellation_request_type_constraint.sql`

### Key Design Decisions
- **Indonesian Localization**: Request types use Indonesian values to match frontend TypeScript enum
- **User Profile Integration**: FK to user_profiles allows PostgREST to auto-resolve joins and provides better user context
- **Company Isolation**: company_id enables multi-tenant data separation with CASCADE delete for consistency
- **Approval Workflow**: Trigger-based automation ensures data integrity when requests are approved
- **Audit Trail**: created_by, approved_by, and reason columns provide complete audit path
- **Flexible Return Handling**: RETURN_ALL automatically creates inventory ledger entries for all DO items

### Migration Files Created (July 10, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260710032924_add_do_cancellation_requests_table_and_trigger.sql` | DO cancellation table + approval trigger | ✅ Created (local) |
| `20260710040026_update_do_cancellation_user_profiles_fk.sql` | Updated FK to user_profiles | ✅ Created (local) |
| `20260710040557_add_do_cancellation_company_id.sql` | Added company_id column | ✅ Created (local) |
| `20260710043728_add_do_cancellation_reason_column.sql` | Added reason column | ✅ Created (local) |
| `20260710050032_update_do_cancellation_request_type_constraint.sql` | Updated CHECK constraint to Indonesian | ✅ Created (local) |

### Pending Tasks
- [x] Create DO cancellation requests system
- [ ] Update `approve_do_cancellation()` function to use Indonesian request_type values
- [ ] Add RLS policies for `do_cancellation_requests` (company isolation)
- [ ] Push 5 migrations to cloud database
- [ ] Update frontend to use new DO cancellation request system
- [ ] Test approval workflow via Supabase Studio

---

## Session Summary: July 12, 2026

### Actions Taken
1. **Environment Management**
   - Started Supabase local development environment successfully
   - All services running correctly on ports 54900-54912
   - Local database backed up to `docs/sql_backup/backup.sql` (66 KB, data only)

2. **Sales Orders Enhancement**
   - Added `po_number` column (text) to `sales_orders` table
   - Updated `view_delivery_report` to include `po_number` and `created_at`
   - Migration: `20260712025751_add_po_number_to_sales_orders.sql`

3. **DO Cancellation System Improvements**
   - **Column Renames**: Removed 'new_' prefix from `do_cancellation_requests` table
     - `new_truck_plate` → `truck_plate`
     - `new_transporter_id` → `transporter_id`
     - `new_sales_order_id` → `sales_order_id`
   - **Function Updates**: Multiple iterations of `approve_do_cancellation()` function
     - Version 1: Indonesian request_type values ('Ganti Kendaraan', 'Ganti Sales Order')
     - Version 2: Added error handling with ROW_COUNT validation
     - Version 3: Simplified logic, removed ROW_COUNT, reordered execution
     - Version 4: Added COALESCE for NULL protection on column updates
     - Version 5: Added cross-company Sales Order logic with SJ regeneration
     - Version 6: Added RETURN_ALL ('Pengembalian Stok (Total)') handling with inventory reversal
   - Migration: `20260712041104_rename_do_cancellation_columns_and_update_function.sql`

4. **RLS Policies Implementation**
   - Enabled RLS on `do_cancellation_requests` table
   - Created `DO Cancellation Access` policy (Superuser + company isolation)
   - Created `Sales Order Access` policy (Superuser full access, users can SELECT all, INSERT/UPDATE own company)
   - Migration: `20260712045220_add_rls_policies_for_do_cancellation_and_sales_orders.sql`

5. **Cross-Company Sales Order Logic**
   - Updated `approve_do_cancellation()` to handle cross-company Sales Order changes
   - When company changes: Auto-generates new SJ number for new company
   - When company same: Only updates Sales Order reference
   - Migration: `20260712060049_update_approve_do_cancellation_with_cross_company_logic.sql`

6. **Delivery Orders Cancellation System**
   - Added `is_cancel` column (boolean, default: false) to `delivery_orders` table
   - Updated `approve_do_cancellation()` to handle RETURN_ALL requests:
     - Marks DO as cancelled (`is_cancel = true`)
     - Loops through each `delivery_order_item`
     - Inserts RETURN entries to `inventory_ledger` for stock restoration
   - Migration: `20260712065726_add_is_cancel_to_delivery_orders_and_update_cancellation_function.sql`

7. **Reporting Views Enhancements**
   - **view_delivery_report** - Multiple updates:
     - Added `is_cancel`, `company_id`, `created_at`, `po_number` columns
     - Added `transporter_name` (from master_partners)
     - Added `truck_plate` (from delivery_order_items)
     - Added `created_by_name` (from user_profiles)
     - Changed to `d_ord.*` for complete column exposure
   - **view_adjustment_report** - Added `created_by_name` (from user_profiles)
   - **view_tcp_report** - Added `created_by_name` (from user_profiles)
   - Migrations: 
     - `20260712071754_update_view_delivery_report_with_is_cancel_column.sql`
     - `20260712074542_update_multiple_reports_views_with_created_by_name.sql`

### Key Design Decisions
- **Column Naming Consistency**: Removed 'new_' prefix for cleaner schema and frontend alignment
- **NULL Protection**: COALESCE prevents accidental NULL overwrites on partial updates
- **Cross-Company Support**: Auto SJ regeneration prevents numbering conflicts when DO changes companies
- **Inventory Reversal**: RETURN_ALL automatically restores stock with proper ledger entries
- **Audit Trail Enhancement**: Added `created_by_name` to all report views for user-friendly display
- **Complete Column Exposure**: `d_ord.*` in views ensures all DO fields are accessible without schema changes

### Function Logic: approve_do_cancellation()
**Current Version Features:**
- ✅ Indonesian request_type values ('Ganti Kendaraan', 'Ganti Sales Order', 'Pengembalian Stok (Total)')
- ✅ Cross-company Sales Order handling with SJ regeneration
- ✅ RETURN_ALL with inventory ledger reversal (RETURN transaction type)
- ✅ NULL-safe updates using COALESCE
- ✅ Company isolation maintained throughout

**Request Types Handled:**
| Request Type | Action | Details |
|--------------|--------|---------|
| 'Ganti Kendaraan' | Update truck info | Updates `truck_plate`, `transporter_id` (COALESCE protected) |
| 'Ganti Sales Order' | Update Sales Order | Cross-company: new SJ + company_id update; Same company: SO only |
| 'Pengembalian Stok (Total)' | Cancel DO + Return stock | Sets `is_cancel=true`, loops items, inserts RETURN ledger entries |

### Migration Files Created (July 12, 2026)
| Migration File | Description | Status |
|----------------|-------------|--------|
| `20260712025751_add_po_number_to_sales_orders.sql` | PO number column + view update | ✅ Pushed |
| `20260712041104_rename_do_cancellation_columns_and_update_function.sql` | Column renames + function updates | ✅ Pushed |
| `20260712045220_add_rls_policies_for_do_cancellation_and_sales_orders.sql` | RLS policies for DO cancellation + sales orders | ✅ Pushed |
| `20260712060049_update_approve_do_cancellation_with_cross_company_logic.sql` | Cross-company SO logic with SJ regeneration | ✅ Pushed |
| `20260712065726_add_is_cancel_to_delivery_orders_and_update_cancellation_function.sql` | is_cancel column + RETURN_ALL handling | ✅ Pushed |
| `20260712071754_update_view_delivery_report_with_is_cancel_column.sql` | View updates with cancel flag | ✅ Pushed |
| `20260712074542_update_multiple_reports_views_with_created_by_name.sql` | Added created_by_name to report views | ✅ Pushed |

### Pending Tasks
- [x] Push 7 new migrations to cloud database ✅
- [ ] Update frontend to use new DO cancellation request system
- [ ] Test cross-company Sales Order changes
- [ ] Test RETURN_ALL inventory reversal workflow
- [ ] Verify report views display created_by_name correctly

---

*This summary is maintained as part of the NSM Backend project documentation.*
