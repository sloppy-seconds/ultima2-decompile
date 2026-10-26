# status_tick_branch — the caller CP5 called undiscovered; its branch SKIPS a block, it does not gate the tick
# name-evidence: reached by fallthrough from asm/0C1C (which asm/0C02 jumps to when
#   [DS:4A] == 0). This fragment sets DS:12 = 4 and then `if [DS:4A] != 0 -> L_000e33`,
#   which is asm/0C33 — the four-counter tick (DS:26B legs, DS:26C arms, DS:26D
#   sleep, DS:26A the fourth). asm/0C2B is the other arm and sets DS:12 = 0xFF.
# WHY THIS MATTERS: W7 was parked because "the caller of asm/0C33..0C53 is
#   undiscovered" and the counters were measured decaying 15 times in ~0.7 s against
#   one PASS. Two things fell out. (1) The search had been looking for L_000c33, which
#   is asm/0A33_cmd_done — the label/file offset confusion again, the same trap that
#   made 0x1240 look like a gap. The tick's label is L_000e33.
# CRITICAL, and an earlier version of this header had it exactly backwards. The `jne L_000e33`
#   JUMPS OVER the world-map block and LANDS ON the tick -- it is not a gate on the tick:
#       c29  jne 0xc33                   ; in a site -> skip 0C2B..0C32, arrive at the tick
#       c2b  mov al,0xff ; mov [DS:12],al
#       c30  call 0x26f9                 ; world-map-only work
#       c33  <tick>                      ; <-- reached by BOTH paths: one by jump, one by fall-through
#   The counters therefore decay everywhere, open world included. The [DS:4A] test only chooses
#   DS:12 = 4 versus 0xFF and whether 0x26f9 runs.
#   RETRACTED 2026-10-26: this header previously asserted the tick ran "only when [DS:4A] != 0,
#   i.e. inside a village/town/castle/tower/dungeon and never on the world map", at confidence:
#   high. Wrong. The engine implemented the mistake as a site gate and stranded the player with
#   permanent paralysis on the open world; the owner caught it by playing, not by reading. The
#   trap is general: when a branch's target is the block immediately after some OTHER block, it
#   is a skip, and calling it a guard requires checking the fall-through first.
# NOT PROVEN: how many times one turn reaches this. The measured 15 decrements in
#   0.7 s is consistent with the damage path being entered repeatedly per turn, but
#   nothing here counts entries, and wiring a per-turn decrement on the strength of
#   this note would be exactly the promotion AGENTS.md § 5 forbids. What would settle
#   it: a breakpoint on L_000e33 counting hits per accepted command.
#   ANSWERED 2026-10-26 WITHOUT A NEW CAPTURE, and the answer is not what this note assumed.
#     captures/spice86/fight-20261021-castle03/turns/ holds 3000 per-turn DS dumps of a real
#     fight, and the counters are plain bytes at DS:26B/26C/26D. Reading the series shows them
#     decaying on turns where HP did NOT change (legs 4->3 with hp delta 0; arms and sleep
#     stepping down with delta 0). So the tick is NOT confined to the damage path, and the
#     once-per-wound model built on this note is wrong. The player also recovered while pinned at
#     one cell for the whole capture with HP still falling, so turns advance even when the player
#     cannot move. Full table: docs/phase4-state.md, section on paralysis stranding.
# func 0C1F..0C2A  len 000C B  evidence: seed+reko
# provenance: static, read 2026-10-27; branch semantics corrected 2026-10-26 by disassembly
# confidence: high for the branch and its target (re-read and corrected); the entry count is open
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
