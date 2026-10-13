-- 2. Nested Sets: Range query using lft/rgt bounds
SELECT c.id, c.name, c.level, c.code, c.parent_id, c.lft, c.rgt
FROM regions root
JOIN regions c ON c.lft BETWEEN root.lft AND root.rgt
WHERE root.name = 'Nairobi';
