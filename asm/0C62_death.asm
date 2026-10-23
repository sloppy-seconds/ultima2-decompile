# death — the death handler: nine zero stores, then the announcement tail
# name-evidence: every site that can kill jumps here, and the span ends in the
#   string ' IS DEAD!'. The jump sites are the food borrow-outs (`jae` at
#   asm/0BDB and asm/0C09), the force field (asm/24B5), Minax's attack (asm/0F8E),
#   dungeon events (asm/12DB, three sites), asm/228D, asm/2495, asm/277B and
#   cmd_L (asm/38B0). Screen-proven: captures/spice86/cp5-weak-fight/death1.png
#   reads `G23MAX IS DEAD!` with H.P., FOOD, EXP and GOLD all at 0000.
# func 0C62..0C81  len 0020 B  evidence: seed+reko
# span: 0C62..0C99 is ONE routine that the bulk wave cut into four fragments, and
#   it only reads as a routine end to end (AGENTS.md: read a span, not a
#   fragment). This file is the zeroing and the repaint; asm/0C82 prints three
#   newlines; asm/0C89 calls L_00527a (asm/507A: bx := 0, print DS:36+bx until a
#   NUL — the character name); asm/0C8C prints ' IS DEAD!' plus a newline. The
#   trailing newline is why the announcement sits on row 22 in the capture and not
#   on the bottom row: it scrolls itself up.
# calls: L_0052f9 (asm/50F9_show_hitpoints — the H.P. line only; the capture shows
#   all four fields repainted, so the wider repaint is observed even though this
#   call is narrow)
# provenance: static, plus the live frame named above. Recorded by hand on
#   2026-10-27 alongside engine/src/game/overworld.c:u2_death, which implements
#   this span; not derived by tools/provenance_from_traces.py.
# confidence: high for the zeroing and the announcement (bytes plus a screen);
#   the four-way fragment cut is mechanical, not semantic
# label: kept as sub_0c62 on purpose — labels are body and CP0 md5s them
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c62:
L_000e62:
        mov    $0x0,%al
L_000e64:
        mov    %al,0x51
L_000e67:
        mov    %al,0x52
L_000e6a:
        mov    %al,0x53
L_000e6d:
        mov    %al,0x54
L_000e70:
        mov    %al,0x55
L_000e73:
        mov    %al,0x56
L_000e76:
        mov    %al,0x57
L_000e79:
        mov    %al,0x58
L_000e7c:
        mov    %al,0x59
L_000e7f:
        call L_0052f9
