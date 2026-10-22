# monster_hp_epilogue — shared tail every monster_hp_* spawn arm jumps into
# name-evidence: 3 bytes, `call L_005cb1`. Reached by `jmp L_000daf` from the end of
#           asm/0D4F_monster_hp_orc, asm/0D6F_monster_hp_thief_daemon,
#           asm/0DAF_monster_hp_sea_serpent and
#           asm/0DC4_monster_hp_fighter_frigate_devil_wizard_balron, i.e. after each
#           arm has stored type and HP. What L_005cb1 does is not established here.
# provenance: static, 2026-10-22
# confidence: low (bytes proven by check_func.py; the callee's behaviour is unknown)
# label: kept as sub_0baf on purpose — labels are body (CP0)
# func 0BAF..0BB1  len 0003 B  evidence: seed+reko
# calls: L_005cb1
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0baf:
L_000daf:
        call L_005cb1
