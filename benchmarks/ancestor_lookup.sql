-- ============================================================================
-- benchmarks/ancestor_lookup.sql
-- Hierarchy Atlas: Ancestor Lookup Benchmark Suite
-- Climbs from a leaf village node up to Country root across all 4 models
-- ============================================================================

-- 1. Adjacency List: Recursive CTE
WITH RECURSIVE ancestors AS (
    SELECT id, name, level, code, parent_id
    FROM regions WHERE id = 3804
    UNION ALL
    SELECT p.id, p.name, p.level, p.code, p.parent_id
    FROM regions p JOIN ancestors a ON p.id = a.parent_id
)
SELECT id, name, level, code, parent_id FROM ancestors;

-- 2. Nested Sets: Envelope bounds inclusion
SELECT a.id, a.name, a.level, a.code, a.parent_id, a.lft, a.rgt
FROM regions node
JOIN regions a ON node.lft BETWEEN a.lft AND a.rgt
WHERE node.id = 3804
ORDER BY a.lft;

-- 3. Closure Table: Direct lookup where descendant_id = target
SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
FROM region_closure c
JOIN regions r ON r.id = c.ancestor_id
WHERE c.descendant_id = 3804
ORDER BY c.depth;

-- 4. ltree: GiST index containment (@>)
SELECT id, name, level, code, parent_id, path
FROM regions
WHERE path @> 'Kenya.Nairobi.Sub_1.Ward_1.Village_1'
ORDER BY path;
