-- 2. Nested Sets: Move Subtree Write (Shifting bounds across table)
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
