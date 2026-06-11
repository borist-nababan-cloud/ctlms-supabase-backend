drop trigger if exists "trg_do_inventory_detail" on "public"."delivery_order_items";

alter table "public"."delivery_order_items" drop constraint "delivery_order_items_shipment_id_fkey";

alter table "public"."delivery_order_items" add constraint "delivery_order_items_shipment_id_fkey" FOREIGN KEY (shipment_id) REFERENCES public.shipments(id) not valid;

alter table "public"."delivery_order_items" validate constraint "delivery_order_items_shipment_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
      DECLARE
        v_company_id uuid;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          SELECT company_id INTO v_company_id FROM public.delivery_orders WHERE id = NEW.do_id;
          INSERT INTO public.inventory_ledger (
            id,
            product_id,
            location,
            qty_change,
            transaction_type,
            reference_id,
            company_id,
            notes
          ) VALUES (
            NEW.id,
            NEW.internal_product_id,
            'STOCKPILE',
            -NEW.net_weight,
            'SALES_OUT',
            NEW.do_id,
            v_company_id,
            'DO Item Truck ' || NEW.truck_plate
          );
          RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
          SELECT company_id INTO v_company_id FROM public.delivery_orders WHERE id = NEW.do_id;
          INSERT INTO public.inventory_ledger (
            id,
            product_id,
            location,
            qty_change,
            transaction_type,
            reference_id,
            company_id,
            notes
          ) VALUES (
            NEW.id,
            NEW.internal_product_id,
            'STOCKPILE',
            -NEW.net_weight,
            'SALES_OUT',
            NEW.do_id,
            v_company_id,
            'DO Item Truck ' || NEW.truck_plate
          )
          ON CONFLICT (id) DO UPDATE SET
            product_id = EXCLUDED.product_id,
            qty_change = EXCLUDED.qty_change,
            company_id = EXCLUDED.company_id,
            notes = EXCLUDED.notes;
          RETURN NEW;
        ELSIF TG_OP = 'DELETE' THEN
          DELETE FROM public.inventory_ledger WHERE id = OLD.id;
          RETURN OLD;
        END IF;
        RETURN NULL;
      END;
      $function$
;

CREATE TRIGGER trg_do_inventory_detail AFTER INSERT OR DELETE OR UPDATE ON public.delivery_order_items FOR EACH ROW EXECUTE FUNCTION public.handle_do_inventory_detail();


