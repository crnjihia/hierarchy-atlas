-- 2. Nested Sets: Envelope inclusion (ancestor.lft <= node.lft AND ancestor.rgt >= node.rgt)
SELECT a.id, a.name, a.level, a.code, a.parent_id, a.lft, a.rgt
FROM regions node
JOIN regions a ON node.lft BETWEEN a.lft AND a.rgt
WHERE node.id = 3804
ORDER BY a.lft;
