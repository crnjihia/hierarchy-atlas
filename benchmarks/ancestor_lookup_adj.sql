-- 1. Adjacency List: Climbing parent chain using recursive CTE
WITH RECURSIVE ancestors AS (
    SELECT id, name, level, code, parent_id
    FROM regions WHERE id = 3804
    UNION ALL
    SELECT p.id, p.name, p.level, p.code, p.parent_id
    FROM regions p JOIN ancestors a ON p.id = a.parent_id
)
SELECT id, name, level, code, parent_id FROM ancestors;
