-- ============================================================================
-- 03_closure_table.sql
-- Hierarchy Atlas: Model 3 - Closure Table
-- Stores explicit ancestor/descendant relationships with depth
-- ============================================================================

-- 1. Schema Definition
CREATE TABLE IF NOT EXISTS region_closure (
    ancestor_id INTEGER NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
    descendant_id INTEGER NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
    depth INTEGER NOT NULL,
    PRIMARY KEY (ancestor_id, descendant_id)
);

-- Fast lookup indexes for both directions (subtree fetch and ancestor traversal)
CREATE INDEX IF NOT EXISTS idx_region_closure_descendant ON region_closure(descendant_id, depth);
CREATE INDEX IF NOT EXISTS idx_region_closure_ancestor ON region_closure(ancestor_id, depth);

-- 2. Populate Closure Table from Adjacency Hierarchy
-- Populates self-referencing rows (depth 0) and all transitive paths
INSERT INTO region_closure (ancestor_id, descendant_id, depth)
WITH RECURSIVE closure_paths AS (
    -- Base case: Self reference at depth 0
    SELECT id AS ancestor_id, id AS descendant_id, 0 AS depth
    FROM regions
    UNION ALL
    -- Recursive case: Connect ancestor of parent to current node
    SELECT cp.ancestor_id, r.id AS descendant_id, cp.depth + 1
    FROM regions r
    JOIN closure_paths cp ON r.parent_id = cp.descendant_id
)
SELECT ancestor_id, descendant_id, depth
FROM closure_paths
ON CONFLICT (ancestor_id, descendant_id) DO NOTHING;

-- 3. Join-based Subtree Fetch Function
CREATE OR REPLACE FUNCTION get_subtree_closure(p_root_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    depth INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
    FROM region_closure c
    JOIN regions r ON r.id = c.descendant_id
    WHERE c.ancestor_id = p_root_id
    ORDER BY c.depth, r.id;
$$;

-- Join-based Subtree Fetch by Region Name
CREATE OR REPLACE FUNCTION get_subtree_closure_by_name(p_name TEXT)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    depth INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
    FROM region_closure c
    JOIN regions r ON r.id = c.descendant_id
    WHERE c.ancestor_id = (SELECT id FROM regions WHERE name = p_name LIMIT 1)
    ORDER BY c.depth, r.id;
$$;

-- Join-based Ancestor Lookup Function
CREATE OR REPLACE FUNCTION get_ancestors_closure(p_node_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    depth INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth
    FROM region_closure c
    JOIN regions r ON r.id = c.ancestor_id
    WHERE c.descendant_id = p_node_id
    ORDER BY c.depth;
$$;

-- 4. Move Subtree Write Operation in Closure Table:
-- Involves deleting stale transitive links and inserting cross-product combinations
CREATE OR REPLACE PROCEDURE move_subtree_closure(p_node_id INTEGER, p_new_parent_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    -- Step 1: Disconnect all nodes in the subtree from all ancestors of the old parent
    DELETE FROM region_closure
    WHERE descendant_id IN (
        SELECT descendant_id FROM region_closure WHERE ancestor_id = p_node_id
    )
    AND ancestor_id IN (
        SELECT ancestor_id FROM region_closure WHERE descendant_id = p_node_id AND ancestor_id <> p_node_id
    );

    -- Step 2: Connect all ancestors of the new parent to all descendants of the moving node
    INSERT INTO region_closure (ancestor_id, descendant_id, depth)
    SELECT super_tree.ancestor_id, sub_tree.descendant_id, super_tree.depth + sub_tree.depth + 1
    FROM region_closure super_tree
    CROSS JOIN region_closure sub_tree
    WHERE super_tree.descendant_id = p_new_parent_id
      AND sub_tree.ancestor_id = p_node_id;

    -- Step 3: Update adjacency parent
    UPDATE regions
    SET parent_id = p_new_parent_id
    WHERE id = p_node_id;
END;
$$;
