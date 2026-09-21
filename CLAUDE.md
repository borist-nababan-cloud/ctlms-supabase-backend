# NSM Backend - Coal Logistics Management System

Supabase-based backend for managing coal procurement, shipping, inventory, sales, and delivery operations.

## Tech Stack

- **Database**: PostgreSQL 17 (via Supabase)
- **Auth**: Supabase Auth with custom user profiles
- **Storage**: Supabase Storage (for ticket images)
- **Edge Functions**: Deno 2 runtime
- **Local Development**: Supabase CLI with Docker

## Project Structure

```
backend/
├── supabase/
│   ├── config.toml           # Supabase configuration
│   ├── migrations/           # Database schema migrations
│   ├── functions/            # Edge functions (Deno/TypeScript)
│   ├── snippets/             # Saved SQL queries
│   └── seed.sql             # Seed data for local development
├── docs/
│   └── notes.md             # Development workflow notes
└── .env                     # Environment variables (not committed)

```

## Core Database Schema

### Master Data Tables
- **`master_partners`** - Suppliers, customers, transporters, and other partners with contact details
- **`master_products`** - Coal products with SKU codes, pricing, and units
- **`master_warehouse`** - Warehouse/facility locations
- **`user_roles`** - Role definitions (bigint ID)
- **`user_profiles`** - User profiles linked to `auth.users`, with role and warehouse assignments

### Operations Tables
- **`shipments`** - Incoming coal shipments from suppliers (vessel, barge, ETA, draft survey quantity)
- **`trucking_logs`** - Truck delivery records (plate, ticket numbers, weights, photo URLs) - **the core tally table**
- **`sales_orders`** - Sales orders to customers (order number, quantity, pricing, delivery type)
- **`delivery_orders`** - Individual delivery records linked to sales orders
- **`inventory_ledger`** - Inventory transaction log (TALLY_IN, SALES_OUT, ADJUSTMENT, BLENDING)

### Key Views
- **`view_inventory_current`** - Current stock levels per product
- **`view_shipment_summary`** - Shipment progress with variance tracking (expected vs actual)
- **`view_shipments_detailed`** - Full shipment details with supplier/product info
- **`view_trucking_summary`** - Trucking logs with shipment context

### Important Triggers
- **`handle_new_tally_log()`** - Automatically creates `inventory_ledger` entries when `trucking_logs` are inserted (TALLY_IN transaction)

## Edge Functions

### `functions/ocr-ticket/index.ts`
Processes weighbridge ticket images using AI vision to extract:
- Truck plate number
- Ticket number
- Gross, tare, and net weights

**Uses**: OpenRouter API with Google Gemini 2.5 Flash model
**Secret**: `OPENROUTER_API_KEY` (set in Supabase Secrets)

## Development Workflow

This project uses a **"Click-and-Save"** workflow recommended for Supabase:

### 1. Start Local Development
```bash
npx supabase start
```
This starts:
- Local PostgreSQL on port 54322
- API on port 54321
- Studio (GUI) on port 54323
- Inbucket (email testing) on port 54324

### 2. Make Changes in Local Studio
Open http://127.0.0.1:54323 and make changes via the Table Editor GUI.

### 3. Generate Migration
```bash
npx supabase db diff -f <descriptive_name>
```
This compares your local database state against migration files and generates a new migration SQL file.

### 4. Push to Cloud
```bash
# Link to remote project (first time only)
npx supabase link --project-ref <your-project-ref>

# Push migrations
npx supabase db push
```

### Stop Local Development
```bash
npx supabase stop
```

## Important Constraints

### ⚠️ Golden Rule
**NEVER** make changes directly in the Cloud Dashboard (supabase.com). Always:
1. Make changes in Local Studio
2. Generate migration with `db diff`
3. Push to cloud with `db push`

### Partner Types
- `SUPPLIER`, `CUSTOMER`, `TRANSPORTER`, `OTHER`

### Product Types
- `INTERNAL_RAW`, `PUBLISHED_FINISHED`

### Delivery Types
- `DIRECT_BARGE`, `STOCKPILE`, `SCHEDULED`

### Inventory Transaction Types
- `TALLY_IN`, `SALES_OUT`, `ADJUSTMENT`, `BLENDING`

### Inventory Locations
- `STOCKPILE`, `BARGE`, `CUSTOMER`

### Sales Order Status
- `DRAFT`, `CONFIRMED`, `COMPLETED`, `CANCELLED`

### Shipment Status
- `planned`, `loading`, `sailing`, `discharging`, `completed`

## Security & RLS

All tables have Row Level Security (RLS) enabled. Current policies allow authenticated users full access to most tables. Consider refining these policies for production based on user roles.

## Environment Variables

Set in `.env` for local development or Supabase Secrets for production:
- `OPENROUTER_API_KEY` - For OCR ticket processing
- `SUPABASE_AUTH_EXTERNAL_*` - OAuth provider secrets (if needed)
