# status_tick_branch — the caller CP5 called undiscovered, and it is a branch on site
# name-evidence: reached by fallthrough from asm/0C1C (which asm/0C02 jumps to when
#   [DS:4A] == 0). This fragment sets DS:12 = 4 and then `if [DS:4A] != 0 -> L_000e33`,
#   which is asm/0C33 — the four-counter tick (DS:26B legs, DS:26C arms, DS:26D
#   sleep, DS:26A the fourth). asm/0C2B is the other arm and sets DS:12 = 0xFF.
# WHY THIS MATTERS: W7 was parked because "the caller of asm/0C33..0C53 is
#   undiscovered" and the counters were measured decaying 15 times in ~0.7 s against
#   one PASS. Two things fell out. (1) The search had been looking for L_000c33, which
#   is asm/0A33_cmd_done — the label/file offset confusion again, the same trap that
#   made 0x1240 look like a gap. The tick's label is L_000e33. (2) The tick is not on
#   a timer at all: it runs on the damage path, and only when [DS:4A] != 0, i.e.
#   inside a village/town/castle/tower/dungeon and never on the world map. That agrees
#   with the one capture that ever saw the counters move, which was in a castle.
# NOT PROVEN: how many times one turn reaches this. The measured 15 decrements in
#   0.7 s is consistent with the damage path being entered repeatedly per turn, but
#   nothing here counts entries, and wiring a per-turn decrement on the strength of
#   this note would be exactly the promotion AGENTS.md § 5 forbids. What would settle
#   it: a breakpoint on L_000e33 counting hits per accepted command.
# func 0C1F..0C2A  len 000C B  evidence: seed+reko
# provenance: static, read 2026-10-27
# confidence: high for the branch and its target; the entry count is open
# label: kept as sub_0c1f on purpose — labels are body and CP0 md5s them
sub_0c1f:
L_000e1f:
        mov    $0x4,%al
L_000e21:
        mov    %al,0x12
L_000e24:
        mov    0x4a,%al
L_000e27:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e29:
        jne L_000e33
