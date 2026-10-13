-- 1. Adjacency List: Move Subtree Write (Reparenting single parent_id pointer)
BEGIN;
UPDATE regions
SET parent_id = CASE WHEN parent_id = 3803 THEN 3808 ELSE 3803 END
WHERE id = 3804;
COMMIT;
