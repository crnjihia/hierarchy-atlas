-- 3. Closure Table: Direct lookup where descendant_id = target
SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
FROM region_closure c
JOIN regions r ON r.id = c.ancestor_id
WHERE c.descendant_id = 3804
ORDER BY c.depth;
