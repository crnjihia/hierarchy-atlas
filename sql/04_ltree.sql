-- ============================================================================
-- 04_ltree.sql
-- Hierarchy Atlas: Model 4 - PostgreSQL ltree Extension
-- Path-indexed hierarchical queries with GiST indexing
-- ============================================================================

-- 1. Enable ltree extension
CREATE EXTENSION IF NOT EXISTS ltree;

-- 2. Add path column and required GiST index
ALTER TABLE regions ADD COLUMN IF NOT EXISTS path LTREE;

-- Exact index specification from technical requirements
CREATE INDEX IF NOT EXISTS idx_regions_path_gist ON regions USING GIST (path);
CREATE INDEX IF NOT EXISTS idx_regions_path_btree ON regions USING BTREE (path);

-- 3. Populate ltree paths deterministically across Kenya hierarchy
-- Normalizes labels to [A-Za-z0-9_] as required by ltree
CREATE OR REPLACE FUNCTION to_ltree_label(raw_text TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(replace(replace(replace(raw_text, ' ', '_'), '-', '_'), '.', '_'), '[^A-Za-z0-9_]', '', 'g');
$$;

DO $$
DECLARE
    r RECORD;
BEGIN
    -- Populate paths starting from roots down the hierarchy
    WITH RECURSIVE ltree_hierarchy AS (
        -- Root level (Kenya)
        SELECT id, to_ltree_label(name)::ltree AS computed_path
        FROM regions
        WHERE parent_id IS NULL
        UNION ALL
        -- Recursive step: County, Sub-County, Ward, Village
        -- County: Kenya.<CountyName>
        -- Sub-County: Kenya.<CountyName>.Sub_<N>
        -- Ward: Kenya.<CountyName>.Sub_<N>.Ward_<M>
        -- Village: Kenya.<CountyName>.Sub_<N>.Ward_<M>.Village_<K>
        SELECT 
            c.id, 
            CASE 
                WHEN c.level = 'County' THEN 
                    (h.computed_path || to_ltree_label(c.name)::ltree)
                WHEN c.level = 'Sub-County' THEN 
                    (h.computed_path || ('Sub_' || regexp_replace(c.name, '.*Sub-(\d+).*', '\1'))::ltree)
                WHEN c.level = 'Ward' THEN 
                    (h.computed_path || ('Ward_' || regexp_replace(c.name, '.*Ward \d+\.(\d+).*', '\1'))::ltree)
                WHEN c.level = 'Village' THEN 
                    (h.computed_path || ('Village_' || regexp_replace(c.name, '.*Village \d+\.\d+\.(\d+).*', '\1'))::ltree)
                ELSE 
                    (h.computed_path || to_ltree_label(c.name)::ltree)
            END AS computed_path
        FROM regions c
        JOIN ltree_hierarchy h ON c.parent_id = h.id
    )
    UPDATE regions reg
    SET path = lh.computed_path
    FROM ltree_hierarchy lh
    WHERE reg.id = lh.id;
END $$;

-- Enforce NOT NULL constraint once populated
ALTER TABLE regions ALTER COLUMN path SET NOT NULL;

-- 4. Subtree Fetch Query & Functions
-- Direct query demonstration matching technical requirements:
-- SELECT * FROM regions WHERE path <@ 'Kenya.Nairobi';
CREATE OR REPLACE FUNCTION get_subtree_ltree(p_path LTREE)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    path LTREE
) LANGUAGE sql STABLE AS $$
    SELECT id, name, level, code, parent_id, path
    FROM regions
    WHERE path <@ p_path
    ORDER BY path;
$$;

-- Subtree Fetch by County Name
CREATE OR REPLACE FUNCTION get_subtree_ltree_by_name(p_name TEXT)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    path LTREE
) LANGUAGE sql STABLE AS $$
    SELECT r.id, r.name, r.level, r.code, r.parent_id, r.path
    FROM regions r
    WHERE r.path <@ (SELECT path FROM regions WHERE name = p_name LIMIT 1)
    ORDER BY r.path;
$$;

-- Ancestor Lookup Query & Function
-- In ltree, parent path contains child path (@> operator)
CREATE OR REPLACE FUNCTION get_ancestors_ltree(p_path LTREE)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    path LTREE
) LANGUAGE sql STABLE AS $$
    SELECT id, name, level, code, parent_id, path
    FROM regions
    WHERE path @> p_path
    ORDER BY path;
$$;

-- 5. Move Subtree Write Operation in ltree:
-- Cascades path replacement across target node and all its descendants via subpath()
CREATE OR REPLACE PROCEDURE move_subtree_ltree(p_node_id INTEGER, p_new_parent_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_old_path LTREE;
    v_new_parent_path LTREE;
    v_node_label TEXT;
    v_new_path LTREE;
    v_old_depth INTEGER;
BEGIN
    SELECT path INTO v_old_path FROM regions WHERE id = p_node_id;
    SELECT path INTO v_new_parent_path FROM regions WHERE id = p_new_parent_id;
    
    v_node_label := subpath(v_old_path, -1, 1)::text;
    v_new_path := v_new_parent_path || v_node_label::ltree;
    v_old_depth := nlevel(v_old_path);

    -- Cascade update across target node and entire descendant tree
    UPDATE regions
    SET path = CASE 
        WHEN nlevel(path) = v_old_depth THEN v_new_path
        ELSE v_new_path || subpath(path, v_old_depth)
    END
    WHERE path <@ v_old_path;

    -- Update adjacency parent
    UPDATE regions
    SET parent_id = p_new_parent_id
    WHERE id = p_node_id;
END;
$$;
