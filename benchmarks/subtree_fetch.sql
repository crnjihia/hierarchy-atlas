-- ============================================================================
-- benchmarks/subtree_fetch.sql
-- Hierarchy Atlas: Subtree Fetch Benchmark Suite
-- Fetches the 131 nodes of Nairobi's administrative hierarchy across all 4 models
-- ============================================================================

-- 1. Adjacency List: Recursive CTE
WITH RECURSIVE subtree AS (
    SELECT id, name, level, code, parent_id
    FROM regions WHERE name = 'Nairobi'
    UNION ALL
    SELECT c.id, c.name, c.level, c.code, c.parent_id
    FROM regions c JOIN subtree s ON c.parent_id = s.id
)
SELECT id, name, level, code, parent_id FROM subtree;

-- 2. Nested Sets: Range query using lft/rgt bounds
SELECT c.id, c.name, c.level, c.code, c.parent_id, c.lft, c.rgt
FROM regions root
JOIN regions c ON c.lft BETWEEN root.lft AND root.rgt
WHERE root.name = 'Nairobi';

-- 3. Closure Table: Join on region_closure
SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
FROM region_closure c
JOIN regions r ON r.id = c.descendant_id
WHERE c.ancestor_id = (SELECT id FROM regions WHERE name = 'Nairobi' LIMIT 1);

-- 4. ltree: GiST index accelerated path containment
SELECT id, name, level, code, parent_id, path
FROM regions
WHERE path <@ 'Kenya.Nairobi';
