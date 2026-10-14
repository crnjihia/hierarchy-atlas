-- ============================================================================
-- 01_adjacency_list.sql
-- Hierarchy Atlas: Model 1 - Adjacency List
-- Administrative Geography: Kenya -> 47 Counties -> Sub-Counties -> Wards -> Villages
-- ============================================================================

-- Drop existing tables to ensure clean initialization
DROP TABLE IF EXISTS region_closure CASCADE;
DROP TABLE IF EXISTS regions CASCADE;

-- 1. Schema Definition
CREATE TABLE regions (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    level TEXT NOT NULL CHECK (level IN ('Country', 'County', 'Sub-County', 'Ward', 'Village')),
    code TEXT,
    parent_id INTEGER REFERENCES regions(id) ON DELETE CASCADE
);

-- Crucial B-Tree index on parent_id for recursive CTE traversal performance
CREATE INDEX idx_regions_parent_id ON regions(parent_id);
CREATE INDEX idx_regions_name ON regions(name);
CREATE INDEX idx_regions_level ON regions(level);

-- 2. Seed Kenya Root and KNBS 47 Counties
DO $$
DECLARE
    v_kenya_id INT;
    v_county RECORD;
    v_county_id INT;
    v_sub_id INT;
    v_ward_id INT;
    s INT;
    w INT;
    v INT;
BEGIN
    -- Insert root country
    INSERT INTO regions (name, level, code, parent_id)
    VALUES ('Kenya', 'Country', 'KE', NULL)
    RETURNING id INTO v_kenya_id;

    -- Array of 47 Kenya Counties from Kenya National Bureau of Statistics (KNBS)
    FOR v_county IN
        SELECT code, name FROM (VALUES
            ('01', 'Mombasa'),
            ('02', 'Kwale'),
            ('03', 'Kilifi'),
            ('04', 'Tana River'),
            ('05', 'Lamu'),
            ('06', 'Taita-Taveta'),
            ('07', 'Garissa'),
            ('08', 'Wajir'),
            ('09', 'Mandera'),
            ('10', 'Marsabit'),
            ('11', 'Isiolo'),
            ('12', 'Meru'),
            ('13', 'Tharaka-Nithi'),
            ('14', 'Embu'),
            ('15', 'Kitui'),
            ('16', 'Machakos'),
            ('17', 'Makueni'),
            ('18', 'Nyandarua'),
            ('19', 'Nyeri'),
            ('20', 'Kirinyaga'),
            ('21', 'Murang''a'),
            ('22', 'Kiambu'),
            ('23', 'Turkana'),
            ('24', 'West Pokot'),
            ('25', 'Samburu'),
            ('26', 'Trans Nzoia'),
            ('27', 'Uasin Gishu'),
            ('28', 'Elgeyo-Marakwet'),
            ('29', 'Nandi'),
            ('30', 'Baringo'),
            ('31', 'Laikipia'),
            ('32', 'Nakuru'),
            ('33', 'Narok'),
            ('34', 'Kajiado'),
            ('35', 'Kericho'),
            ('36', 'Bomet'),
            ('37', 'Kakamega'),
            ('38', 'Vihiga'),
            ('39', 'Bungoma'),
            ('40', 'Busia'),
            ('41', 'Siaya'),
            ('42', 'Kisumu'),
            ('43', 'Homa Bay'),
            ('44', 'Migori'),
            ('45', 'Kisii'),
            ('46', 'Nyamira'),
            ('47', 'Nairobi')
        ) AS c(code, name)
    LOOP
        -- Insert County
        INSERT INTO regions (name, level, code, parent_id)
        VALUES (v_county.name, 'County', v_county.code, v_kenya_id)
        RETURNING id INTO v_county_id;

        -- Generate 5 Sub-Counties per County (235 sub-counties total)
        FOR s IN 1..5 LOOP
            INSERT INTO regions (name, level, code, parent_id)
            VALUES (v_county.name || ' Sub-' || s, 'Sub-County', v_county.code || '-' || s, v_county_id)
            RETURNING id INTO v_sub_id;

            -- Generate 5 Wards per Sub-County (1,175 wards total)
            FOR w IN 1..5 LOOP
                INSERT INTO regions (name, level, code, parent_id)
                VALUES (v_county.name || ' Ward ' || s || '.' || w, 'Ward', v_county.code || '-' || s || '-' || w, v_sub_id)
                RETURNING id INTO v_ward_id;

                -- Generate 4 Villages per Ward (4,700 villages total)
                FOR v IN 1..4 LOOP
                    INSERT INTO regions (name, level, code, parent_id)
                    VALUES (v_county.name || ' Village ' || s || '.' || w || '.' || v, 'Village', NULL, v_ward_id);
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- 3. Recursive CTE Subtree Fetch Query & Views
-- Subtree Fetch: Given a root region id, recursively returns all its descendants
CREATE OR REPLACE FUNCTION get_subtree_adj(p_root_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    depth INTEGER
) LANGUAGE sql STABLE AS $$
    WITH RECURSIVE subtree AS (
        SELECT r.id, r.name, r.level, r.code, r.parent_id, 0 AS depth
        FROM regions r
        WHERE r.id = p_root_id
        UNION ALL
        SELECT c.id, c.name, c.level, c.code, c.parent_id, s.depth + 1
        FROM regions c
        JOIN subtree s ON c.parent_id = s.id
    )
    SELECT * FROM subtree;
$$;

-- Subtree Fetch by Region Name
CREATE OR REPLACE FUNCTION get_subtree_adj_by_name(p_name TEXT)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    depth INTEGER
) LANGUAGE sql STABLE AS $$
    WITH RECURSIVE subtree AS (
        SELECT r.id, r.name, r.level, r.code, r.parent_id, 0 AS depth
        FROM regions r
        WHERE r.name = p_name
        UNION ALL
        SELECT c.id, c.name, c.level, c.code, c.parent_id, s.depth + 1
        FROM regions c
        JOIN subtree s ON c.parent_id = s.id
    )
    SELECT * FROM subtree;
$$;

-- Ancestor Lookup: Given a node id, recursively climbs the parent chain to the root
CREATE OR REPLACE FUNCTION get_ancestors_adj(p_node_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    name TEXT,
    level TEXT,
    code TEXT,
    parent_id INTEGER,
    depth INTEGER
) LANGUAGE sql STABLE AS $$
    WITH RECURSIVE ancestors AS (
        SELECT r.id, r.name, r.level, r.code, r.parent_id, 0 AS depth
        FROM regions r
        WHERE r.id = p_node_id
        UNION ALL
        SELECT p.id, p.name, p.level, p.code, p.parent_id, a.depth + 1
        FROM regions p
        JOIN ancestors a ON p.id = a.parent_id
    )
    SELECT * FROM ancestors;
$$;

-- View: Pre-defined subtree view for Nairobi county
CREATE OR REPLACE VIEW regions_adj_nairobi_subtree AS
SELECT * FROM get_subtree_adj_by_name('Nairobi');

-- Move Subtree Write Operation in Adjacency List:
-- An O(1) single-row update that reparents an entire sub-hierarchy
CREATE OR REPLACE PROCEDURE move_subtree_adj(p_node_id INTEGER, p_new_parent_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE regions
    SET parent_id = p_new_parent_id
    WHERE id = p_node_id;
END;
$$;
