-- 4. ltree: Path prefix query (<@)
SELECT id, name, level, code, parent_id, path
FROM regions
WHERE path <@ 'Kenya.Nairobi';
