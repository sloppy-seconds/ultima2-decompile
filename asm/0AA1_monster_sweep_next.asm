# 0AA1_monster_sweep_next — `dec %di ; jne L_000c74`: next slot down, else leave the sweep
# name-evidence: the only backward branch to the sweep body; when DI reaches 0 the loop
#           falls through to asm/0AA4_monster_spawn_entry instead of jumping, which is
#           why no `call` or `jmp` names the spawner from outside (see § 11's note that a
#           call-only caller search concludes the cluster is dead code).
# Slots run 31 down to 1; slot 0 is never examined, the same blind spot as
# asm/23E6_find_creature_at_cursor.asm (docs/monster-spawn.md § 11).
# label: kept as sub_0aa1 on purpose (CP3 cross-reference anchor).
# func 0AA1..0AA3  len 0003 B  evidence: seed+reko
# provenance: static reassembly 2026-10-28 (docs/monster-spawn.md § 15.2)
# confidence: high (bytes proven by check_func.py; the loop-back target is named here)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0aa1:
L_000ca1:
        dec    %di
L_000ca2:
        jne L_000c74
