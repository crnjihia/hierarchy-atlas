-- 1. Adjacency List: Recursive CTE Subtree Fetch
WITH RECURSIVE subtree AS (
    SELECT id, name, level, code, parent_id
    FROM regions WHERE name = 'Nairobi'
    UNION ALL
    SELECT c.id, c.name, c.level, c.code, c.parent_id
    FROM regions c JOIN subtree s ON c.parent_id = s.id
)
SELECT id, name, level, code, parent_id FROM subtree;
