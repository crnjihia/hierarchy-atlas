-- ============================================================================
-- benchmarks/move_subtree.sql
-- Hierarchy Atlas: Move Subtree Benchmark Suite
-- Demonstrates write amplification across all 4 models
-- ============================================================================

-- 1. Adjacency List: O(1) single-row parent pointer swap
BEGIN;
UPDATE regions
SET parent_id = CASE WHEN parent_id = 3803 THEN 3808 ELSE 3803 END
WHERE id = 3804;
COMMIT;

-- 2. Nested Sets: Bound shifting across hierarchy
BEGIN;
DO $$
DECLARE
    v_cur_parent INT;
    v_target INT;
BEGIN
    SELECT parent_id INTO v_cur_parent FROM regions WHERE id = 3804;
    IF v_cur_parent = 3803 THEN v_target := 3808; ELSE v_target := 3803; END IF;
    CALL move_subtree_nested(3804, v_target);
END $$;
COMMIT;

-- 3. Closure Table: Rebuilding transitive closure connections
BEGIN;
DO $$
DECLARE
    v_cur_parent INT;
    v_target INT;
BEGIN
    SELECT parent_id INTO v_cur_parent FROM regions WHERE id = 3804;
    IF v_cur_parent = 3803 THEN v_target := 3808; ELSE v_target := 3803; END IF;
    CALL move_subtree_closure(3804, v_target);
END $$;
COMMIT;

-- 4. ltree: Path cascading prefix update via subpath()
BEGIN;
DO $$
DECLARE
    v_cur_parent INT;
    v_target INT;
BEGIN
    SELECT parent_id INTO v_cur_parent FROM regions WHERE id = 3804;
    IF v_cur_parent = 3803 THEN v_target := 3808; ELSE v_target := 3803; END IF;
    CALL move_subtree_ltree(3804, v_target);
END $$;
COMMIT;
