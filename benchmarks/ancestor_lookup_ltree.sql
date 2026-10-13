-- 4. ltree: GiST-accelerated ancestor containment (@>)
SELECT id, name, level, code, parent_id, path
FROM regions
WHERE path @> 'Kenya.Nairobi.Sub_1.Ward_1.Village_1'
ORDER BY path;
