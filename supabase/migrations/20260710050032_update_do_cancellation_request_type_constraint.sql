alter table "public"."do_cancellation_requests" drop constraint "do_cancellation_requests_request_type_check";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_request_type_check" CHECK ((request_type = ANY (ARRAY['Ganti Kendaraan'::text, 'Ganti Sales Order'::text, 'Pengembalian Stok (Per Item)'::text, 'Pengembalian Stok (Total)'::text]))) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_request_type_check";


