-- CS-06-P2B: CANCELLED - Design Conflict with CS-02
--
-- inventory_balances sudah ada sebagai VIEW dari CS-02 (20260906172811):
--   SELECT m.business_id, l.stock_item_id, l.location_id,
--          sum(l.quantity_delta)::numeric(18,3) AS quantity
--   FROM inventory_movements m
--   JOIN inventory_movement_lines l ON l.movement_id = m.id
--   GROUP BY m.business_id, l.stock_item_id, l.location_id;
--
-- Model inventory CS-02 sudah mature:
--   - stock_items (item master, bukan products)
--   - inventory_movements + inventory_movement_lines (immutable fact)
--   - inventory_balances (view agregat)
--
-- Desain P2B asli (CREATE TABLE inventory_balances dengan product_id)
-- konflik dengan view ini dan TIDAK di-apply ke DB.
-- P2B akan didesain ulang untuk integrasi products (P1) dengan stock_items (CS-02).

select 1;
