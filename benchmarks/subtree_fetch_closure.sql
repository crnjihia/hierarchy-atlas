-- 3. Closure Table: Direct join on region_closure
SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
FROM region_closure c
JOIN regions r ON r.id = c.descendant_id
WHERE c.ancestor_id = (SELECT id FROM regions WHERE name = 'Nairobi' LIMIT 1);
