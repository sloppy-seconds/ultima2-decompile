# 0A15_invalid_move_to_cmd_done — the invalid-move path's tail: jumps into cmd_done, so a refused step is a completed command
# name-evidence: reached only by fall-through from asm/0A02_invalid_move_msg after it prints the
#           reject string, and its single instruction is `jmp L_000c30`, which is asm/0A30, a 3-byte
#           `call` that falls straight through to asm/0A33_cmd_done. Verified from the raw bytes at
#           file 0C15 (`eb 19` -> 0C30) on 2026-10-26, not inferred.
# WHY THIS MATTERS: it settles whether the creature sweep runs on a REFUSED step. The chain is
#           refused step -> asm/0A02 (prints --INVALID MOVE!) -> this jmp -> asm/0A30 -> fall through
#           to asm/0A33_cmd_done -> fall through to asm/0A38_post_command_tail -> the sweep. So it
#           does: bumping into a wall is a handled, completed command, and the world takes its full
#           turn. Corroborated live the same day: in sector 03, 16 of 19 direction keys were refused
#           and creature coordinates changed on 12 of them.
#           The engine had the opposite behaviour - its reject paths `continue` without
#           creature_turn() (engine/src/game/overworld.c) - which is a fidelity bug, not a choice.
# func 0A15..0A17  len 0003 B  evidence: seed+reko
# calls: L_000c30
# provenance: static — raw bytes read from the executable at file 0C15 on 2026-10-26 (`eb 19`,
#           target 0C30), plus the fall-through arithmetic at asm/0A30 (a 3-byte near call, so
#           0A30..0A32 and cmd_done begins at 0A33). Corroborated live the same day in sector 03: 16
#           refused direction keys, creature coordinates changed on 12 of them. The corroboration is
#           a recording under /var/tmp and is NOT committed; the byte-level chain stands alone.
# confidence: high for the flow (bytes plus live corroboration)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a15:
L_000c15:
        jmp L_000c30
L_000c17:
        nop
