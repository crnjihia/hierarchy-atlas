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
            ('01', 'Baringo'),
            ('02', 'Bomet'),
            ('03', 'Bungoma'),
            ('04', 'Busia'),
            ('05', 'Elgeyo-Marakwet'),
            ('06', 'Embu'),
            ('07', 'Garissa'),
            ('08', 'Homa Bay'),
            ('09', 'Isiolo'),
            ('10', 'Kajiado'),
            ('11', 'Kakamega'),
            ('12', 'Kericho'),
            ('13', 'Kiambu'),
            ('14', 'Kilifi'),
            ('15', 'Kirinyaga'),
            ('16', 'Kisii'),
            ('17', 'Kisumu'),
            ('18', 'Kitui'),
            ('19', 'Kwale'),
            ('20', 'Laikipia'),
            ('21', 'Lamu'),
            ('22', 'Machakos'),
            ('23', 'Makueni'),
            ('24', 'Mandera'),
            ('25', 'Marsabit'),
            ('26', 'Meru'),
            ('27', 'Migori'),
            ('28', 'Mombasa'),
            ('29', 'Murang''a'),
            ('30', 'Nairobi'),
            ('31', 'Nakuru'),
            ('32', 'Nandi'),
            ('33', 'Narok'),
            ('34', 'Nyamira'),
            ('35', 'Nyandarua'),
            ('36', 'Nyeri'),
            ('37', 'Samburu'),
            ('38', 'Siaya'),
            ('39', 'Taita-Taveta'),
            ('40', 'Tana River'),
            ('41', 'Tharaka-Nithi'),
            ('42', 'Trans Nzoia'),
            ('43', 'Turkana'),
            ('44', 'Uasin Gishu'),
            ('45', 'Vihiga'),
            ('46', 'West Pokot'),
            ('47', 'Wajir')
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
