-- ============================================================================
-- 02_nested_sets.sql
-- Hierarchy Atlas: Model 2 - Nested Sets
-- Extends regions with lft and rgt bounds for O(1) subtree reads
-- ============================================================================

-- 1. Add lft and rgt columns
ALTER TABLE regions ADD COLUMN IF NOT EXISTS lft INTEGER;
ALTER TABLE regions ADD COLUMN IF NOT EXISTS rgt INTEGER;

-- Composite B-Tree index on bounds for ultra-fast range queries
CREATE INDEX IF NOT EXISTS idx_regions_lft_rgt ON regions (lft, rgt);
CREATE INDEX IF NOT EXISTS idx_regions_rgt ON regions (rgt);

-- 2. Procedure to populate / rebuild nested sets bounds via Depth-First Traversal
CREATE OR REPLACE FUNCTION nset_traverse_node(p_node_id INTEGER, p_counter INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_child_id INTEGER;
    v_cur INTEGER := p_counter;
BEGIN
    -- Assign left bound
    UPDATE regions SET lft = v_cur WHERE id = p_node_id;
    v_cur := v_cur + 1;

    -- Recurse through all direct children
    FOR v_child_id IN 
        SELECT id FROM regions WHERE parent_id = p_node_id ORDER BY id 
    LOOP
        v_cur := nset_traverse_node(v_child_id, v_cur);
    END LOOP;

    -- Assign right bound
    UPDATE regions SET rgt = v_cur WHERE id = p_node_id;
    RETURN v_cur + 1;
END;
$$;

-- Populate nested set bounds for Kenya and all its descendants
DO $$
DECLARE
    v_root_id INTEGER;
BEGIN
    SELECT id INTO v_root_id FROM regions WHERE parent_id IS NULL LIMIT 1;
    IF v_root_id IS NOT NULL THEN
        PERFORM nset_traverse_node(v_root_id, 1);
    END IF;
END $$;

-- 3. O(1) Subtree Read Function
-- Fetches the entire subtree using a single BETWEEN comparison on lft/rgt bounds
CREATE OR REPLACE FUNCTION get_subtree_nested(p_root_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    lft INTEGER,
    rgt INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT c.id, c.name, c.level, c.code, c.parent_id, c.lft, c.rgt
    FROM regions root
    JOIN regions c ON c.lft BETWEEN root.lft AND root.rgt
    WHERE root.id = p_root_id
    ORDER BY c.lft;
$$;

-- O(1) Subtree Read by Region Name
CREATE OR REPLACE FUNCTION get_subtree_nested_by_name(p_name TEXT)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    lft INTEGER,
    rgt INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT c.id, c.name, c.level, c.code, c.parent_id, c.lft, c.rgt
    FROM regions root
    JOIN regions c ON c.lft BETWEEN root.lft AND root.rgt
    WHERE root.name = p_name
    ORDER BY c.lft;
$$;

-- Ancestor Lookup in Nested Sets:
-- All ancestors satisfy: ancestor.lft <= node.lft AND ancestor.rgt >= node.rgt
CREATE OR REPLACE FUNCTION get_ancestors_nested(p_node_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    lft INTEGER,
    rgt INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT a.id, a.name, a.level, a.code, a.parent_id, a.lft, a.rgt
    FROM regions node
    JOIN regions a ON node.lft BETWEEN a.lft AND a.rgt
    WHERE node.id = p_node_id
    ORDER BY a.lft;
$$;

-- 4. Expensive Write Demonstration: Moving a Subtree (Shifting Bounds)
-- In nested sets, moving a node with its subtree requires shifting bounds across
-- the entire tree to close the vacated space and make room at the new parent.
CREATE OR REPLACE PROCEDURE move_subtree_nested(p_node_id INTEGER, p_new_parent_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_sub_lft INTEGER;
    v_sub_rgt INTEGER;
    v_sub_width INTEGER;
    v_new_parent_rgt INTEGER;
    v_offset INTEGER;
BEGIN
    -- Read current subtree bounds
    SELECT lft, rgt INTO v_sub_lft, v_sub_rgt FROM regions WHERE id = p_node_id;
    v_sub_width := v_sub_rgt - v_sub_lft + 1;

    -- Read target parent's right bound
    SELECT rgt INTO v_new_parent_rgt FROM regions WHERE id = p_new_parent_id;

    -- Step 1: Temporarily invert bounds of moving subtree to protect them from global shifts
    UPDATE regions
    SET lft = -lft, rgt = -rgt
    WHERE lft BETWEEN v_sub_lft AND v_sub_rgt;

    -- Step 2: Close gap left by moving subtree
    UPDATE regions
    SET lft = lft - v_sub_width
    WHERE lft > v_sub_rgt;

    UPDATE regions
    SET rgt = rgt - v_sub_width
    WHERE rgt > v_sub_rgt;

    -- Re-read new parent's rgt after closing gap (in case target parent was to the right)
    SELECT rgt INTO v_new_parent_rgt FROM regions WHERE id = p_new_parent_id;

    -- Step 3: Open space of size v_sub_width at destination
    UPDATE regions
    SET lft = lft + v_sub_width
    WHERE lft >= v_new_parent_rgt;

    UPDATE regions
    SET rgt = rgt + v_sub_width
    WHERE rgt >= v_new_parent_rgt;

    -- Step 4: Calculate new offset and restore subtree bounds into the opened space
    v_offset := v_new_parent_rgt - v_sub_lft;
    UPDATE regions
    SET lft = -lft + v_offset,
        rgt = -rgt + v_offset
    WHERE lft < 0;

    -- Step 5: Update adjacency parent
    UPDATE regions
    SET parent_id = p_new_parent_id
    WHERE id = p_node_id;
END;
$$;
