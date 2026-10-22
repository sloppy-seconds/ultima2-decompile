# monster_hp_set — store a value into monster HP [DI+0x177], then call L_00543e
# name-evidence: 7 bytes; `mov %al,0x177(%di)` followed by `call L_00543e`. [DI+0x177]
#           is monster HP (proven by asm/2E3D_combat_attack_flow), so this is the
#           setter used when the value is not a per-kind immediate — the counterpart
#           to the spawn arms. asm/212A does `incb 0x177(%di)` on the same field.
# provenance: static, 2026-10-22
# confidence: low (bytes proven by check_func.py; callers not traced)
# label: kept as sub_2c26 on purpose — labels are body (CP0)
# func 2C26..2C2C  len 0007 B  evidence: seed+reko
# calls: L_00543e
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2c26:
L_002e26:
        mov    %al,0x177(%di)
L_002e2a:
        call L_00543e
