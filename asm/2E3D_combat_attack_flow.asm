# combat_attack_flow — player attack resolution (hit/kill/miss)
# name-evidence: strings 'HIT!' + 'KILLED--GOLD+'; 306 B combat routine
# HP FIELD PROVEN here, 2026-10-22 (this is the strongest evidence in the tree for
#   what [DI+0x177] is). At runtime 0x30BD:
#     mov 0x177(%di),%al   ; load monster HP
#     stc; cmc             ; clear CF for a no-borrow subtract
#     sbb 0x20,%al         ; HP -= the damage byte just stored at [DS:20]
#     cmc                  ; re-expose the borrow (the BCD idiom AGENTS.md warns about:
#                          ;   a cmp-based detector calls this unguarded and under-counts)
#     jae -> mov %al,0x177(%di)          ; survived, store the reduced HP
#     else -> 0x177=0, 0x197=0, 0x1b7=0  ; died, whole record cleared
#   So [DI+0x177] is decremented by the player's damage and its exhaustion is what
#   kills the monster. That is what makes the monster_hp_* spawn arms readable:
#   they store per-kind HP immediates into this field.
#   LIVE CAVEAT (2026-10-22, corrected same day): the arm immediate is the BASE HP of
#   an ordinary wandering spawn, and the area can raise it. The capture corpus shows
#   ~40 dumps where live HP equals the arm exactly (baseline-fight, probe, scrollfix,
#   u2-vendored, bandhash, sweep* ...). castle-03-live shows a Thief (base 32) at
#   100/150/200/250 and a Devil (base 192) at 255, i.e. buffed, alongside damaged
#   values (Fighter 100 of 128, Devil 187 of 192). The sector-0 compound saturates
#   every slot to 255. So a single 255-everywhere reading does NOT disprove the arms;
#   check the area before concluding. See docs/bestiary.md § 6.
# func 2E3D..2F6E  len 0132 B  evidence: reko
# strings: "HIT!"; "--EXP.+"; "MISS"
# calls: L_000c33, L_001651, L_00307d, L_003164, L_0051df (str_out), L_005417, L_00543e, L_0055b5 (+1 more)
# provenance: live:airport32 (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
#
# ---------------------------------------------------------------------------
# FLOW DECODED 2026-10-23 (CP5 W3 prep). File offsets below are the L_<hex> labels
# in this file, i.e. runtime + 0x200 (AGENTS.md: file_offset = offset + 0x200).
#
# Target scan (file 0x303D..0x307A): slot index starts at 0x1F and counts DOWN
# through [DS:1F]; a slot matches when [DI+0x137]==[DS:23] and [DI+0x157]==[DS:24]
# and [DI+0x1B7]==[DS:25]. No match -> MISS (file 0x3164). NOTE [DS:23]/[DS:24] are
# the same scratch the walk loop uses for the player cell, and [DS:25] is
# reserved_25 in state.h: this routine is matching a TARGET triple, so the
# direction handler upstream must be filling them. Not yet traced — do not assume
# "adjacent cell" from the live behaviour without checking that path.
#
# HIT TEST (file 0x307E..0x3088) — proven:
#     call L_005417          ; rand_byte
#     clc; rcr $1,%al        ; al = rand >> 1
#     cmp    0x4c,%al        ; DS:4C = stat_agi
#     jb  -> HIT   else MISS
#   so a hit needs (rand >> 1) < agility. agility 0 can never hit; 0xFF always can.
#
# DAMAGE (file 0x309F..0x30BA) — shape proven, magnitude NOT:
#     al = [DS:61]; add al,al x3        ; al = 8 * [DS:61]
#     adc [DS:4B],al                    ; + stat_str (+ CF)
#     clc; rcr $1,al; clc; rcr $1,al    ; >> 2
#     mov %al,[DS:20]                   ; the damage byte
#   => damage = (strength + 8 * [DS:61]) >> 2.
#   [DS:61] is readied_weapon in state.h, but the wield INDEX does not reproduce
#   the observed number: at str 40 with QUICK SWORD (wield 9) the formula on the
#   index gives 28, while two live kills each removed exactly 34 (Guard 255->221
#   in captures/spice86/cp5-guard-aggro, Fighter 50->16 in cp5-weak-fight).
#   34 is what the formula yields for a weapon value of 12, and three calls sit
#   between the HIT print and the read (L_00543e, L_0060d7, L_00543e) — so [DS:61]
#   is almost certainly a weapon DAMAGE value resolved by the undecoded L_0060d7,
#   not the wield index. OPEN: decode L_0060d7 and the weapon table it fills.
#
# HP SUBTRACT AND DEATH (file 0x30BC..0x30DC) — proven, and note the branch sense:
#     al = [DI+0x177]; stc; cmc; sbb [DS:20],al; cmc
#     jae -> (CF clear after cmc means hp < damage) -> DEATH branch
#     fallthrough -> store hp-damage (so hp == damage leaves a LIVE monster at 0)
#   Death clears [DI+0x177] hp, [DI+0x197] type and [DI+0x1B7] kind — and NOT
#   [DI+0x137]/[DI+0x157] x/y. It then copies the dead monster's x,y into
#   [DS:23]/[DS:24] and clears the high nibble of that map cell via [DS:8], which
#   is the monster stamp being removed.
#
# REWARD (file 0x3114..0x3161) — proven, and it matches live exactly:
#   gold += (rand & 0x17) | 1   BCD adc into [DS:59] then [DS:58]
#   exp  +=  rand & 0x07        BCD adc into [DS:57] then [DS:56]
#   Live: `KILLED--GOLD+1--EXP.+02` on a character at 9999 in both fields, which
#   wrapped them to 0010 and 0001 — the BCD wrap the B1 ticket predicts, seen on
#   screen (captures/spice86/cp5-fight/screen4.png).
#
# What the engine still lacks to implement this: the [DS:61] weapon table, the
# upstream that fills [DS:23]/[DS:24]/[DS:25] for an attack, and L_0055b5 (called
# before each BCD add — probably the numeric print, unconfirmed).
# ---------------------------------------------------------------------------
combat_attack_flow:
L_00303d:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_00303f:
        .byte 0xb3,0x1f  # forced-kept: gas re-encodes 'mov    $0x1f,%bl' differently
L_003041:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_003043:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_003045:
        .byte 0x88,0x1e,0x1f,0x00  # forced-kept: gas re-encodes 'mov    %bl,0x1f' differently
L_003049:
        .byte 0x8a,0x85,0x37,0x01  # forced-kept: gas re-encodes 'mov    0x137(%di),%al' differently
L_00304d:
        .byte 0x3a,0x06,0x23,0x00  # forced-kept: gas re-encodes 'cmp    0x23,%al' differently
L_003051:
        jne L_00306a
L_003053:
        .byte 0x8a,0x85,0x57,0x01  # forced-kept: gas re-encodes 'mov    0x157(%di),%al' differently
L_003057:
        .byte 0x3a,0x06,0x24,0x00  # forced-kept: gas re-encodes 'cmp    0x24,%al' differently
L_00305b:
        jne L_00306a
L_00305d:
        .byte 0x8a,0x85,0xb7,0x01  # forced-kept: gas re-encodes 'mov    0x1b7(%di),%al' differently
L_003061:
        .byte 0x3a,0x06,0x25,0x00  # forced-kept: gas re-encodes 'cmp    0x25,%al' differently
L_003065:
        jne L_00306a
L_003067:
        jmp L_00307d
L_003069:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_00306a:
        decb   0x1f
L_00306e:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_003070:
        .byte 0x8a,0x1e,0x1f,0x00  # forced-kept: gas re-encodes 'mov    0x1f,%bl' differently
L_003074:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_003076:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003078:
        jne L_003049
L_00307a:
        jmp L_003164
L_00307d:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_00307e:
        call L_005417
L_003081:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_003082:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_003084:
        .byte 0x3a,0x06,0x4c,0x00  # forced-kept: gas re-encodes 'cmp    0x4c,%al' differently
L_003088:
        jb L_00308d
L_00308a:
        jmp L_003164
L_00308d:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_00308e:
        call L_0051df
        db "HIT!",0x00        # string
L_003096:
        call L_00543e
L_003099:
        call L_0060d7
L_00309c:
        call L_00543e
L_00309f:
        .byte 0xa0,0x61,0x00  # forced-kept: gas re-encodes 'mov    0x61,%al' differently
L_0030a2:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0030a4:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0030a6:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0030a8:
        .byte 0x12,0x06,0x4b,0x00  # forced-kept: gas re-encodes 'adc    0x4b,%al' differently
L_0030ac:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_0030ad:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_0030af:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_0030b0:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_0030b2:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_0030b4:
        .byte 0x8a,0x1e,0x1f,0x00  # forced-kept: gas re-encodes 'mov    0x1f,%bl' differently
L_0030b8:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0030ba:
        .byte 0xa2,0x20,0x00  # forced-kept: gas re-encodes 'mov    %al,0x20' differently
L_0030bd:
        .byte 0x8a,0x85,0x77,0x01  # forced-kept: gas re-encodes 'mov    0x177(%di),%al' differently
L_0030c1:
        .byte 0xf9  # forced-kept: gas re-encodes 'stc' differently
L_0030c2:
        .byte 0xf5  # forced-kept: gas re-encodes 'cmc' differently
L_0030c3:
        .byte 0x1a,0x06,0x20,0x00  # forced-kept: gas re-encodes 'sbb    0x20,%al' differently
L_0030c7:
        .byte 0xf5  # forced-kept: gas re-encodes 'cmc' differently
L_0030c8:
        jae L_0030d1
L_0030ca:
        .byte 0x88,0x85,0x77,0x01  # forced-kept: gas re-encodes 'mov    %al,0x177(%di)' differently
L_0030ce:
        jmp L_000c33
L_0030d1:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_0030d2:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_0030d4:
        .byte 0x88,0x85,0x77,0x01  # forced-kept: gas re-encodes 'mov    %al,0x177(%di)' differently
L_0030d8:
        .byte 0x88,0x85,0x97,0x01  # forced-kept: gas re-encodes 'mov    %al,0x197(%di)' differently
L_0030dc:
        .byte 0x88,0x85,0xb7,0x01  # forced-kept: gas re-encodes 'mov    %al,0x1b7(%di)' differently
L_0030e0:
        .byte 0x8a,0x85,0x37,0x01  # forced-kept: gas re-encodes 'mov    0x137(%di),%al' differently
L_0030e4:
        .byte 0xa2,0x23,0x00  # forced-kept: gas re-encodes 'mov    %al,0x23' differently
L_0030e7:
        .byte 0x8a,0x85,0x57,0x01  # forced-kept: gas re-encodes 'mov    0x157(%di),%al' differently
L_0030eb:
        .byte 0xa2,0x24,0x00  # forced-kept: gas re-encodes 'mov    %al,0x24' differently
L_0030ee:
        .byte 0xa0,0x25,0x00  # forced-kept: gas re-encodes 'mov    0x25,%al' differently
L_0030f1:
        call L_001651
L_0030f4:
        .byte 0x8b,0x1e,0x08,0x00  # forced-kept: gas re-encodes 'mov    0x8,%bx' differently
L_0030f8:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_0030fa:
        .byte 0x24,0xf0  # forced-kept: gas re-encodes 'and    $0xf0,%al' differently
L_0030fc:
        .byte 0x8b,0x1e,0x08,0x00  # forced-kept: gas re-encodes 'mov    0x8,%bx' differently
L_003100:
        .byte 0x88,0x00  # forced-kept: gas re-encodes 'mov    %al,(%bx,%si)' differently
L_003102:
        call L_0051df
        db 0x8d,"KILLED--GOLD+",0x00        # string
L_003114:
        call L_005417
L_003117:
        .byte 0x24,0x17  # forced-kept: gas re-encodes 'and    $0x17,%al' differently
L_003119:
        .byte 0x0c,0x01  # forced-kept: gas re-encodes 'or     $0x1,%al' differently
L_00311b:
        .byte 0xa2,0x20,0x00  # forced-kept: gas re-encodes 'mov    %al,0x20' differently
L_00311e:
        call L_0055b5
L_003121:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_003122:
        .byte 0xa0,0x59,0x00  # forced-kept: gas re-encodes 'mov    0x59,%al' differently
L_003125:
        .byte 0x12,0x06,0x20,0x00  # forced-kept: gas re-encodes 'adc    0x20,%al' differently
L_003129:
        .byte 0x27  # forced-kept: gas re-encodes 'daa' differently
L_00312a:
        .byte 0xa2,0x59,0x00  # forced-kept: gas re-encodes 'mov    %al,0x59' differently
L_00312d:
        .byte 0xa0,0x58,0x00  # forced-kept: gas re-encodes 'mov    0x58,%al' differently
L_003130:
        .byte 0x14,0x00  # forced-kept: gas re-encodes 'adc    $0x0,%al' differently
L_003132:
        .byte 0x27  # forced-kept: gas re-encodes 'daa' differently
L_003133:
        .byte 0xa2,0x58,0x00  # forced-kept: gas re-encodes 'mov    %al,0x58' differently
L_003136:
        call L_0051df
        db "--EXP.+",0x00        # string
L_003141:
        call L_005417
L_003144:
        .byte 0x24,0x07  # forced-kept: gas re-encodes 'and    $0x7,%al' differently
L_003146:
        .byte 0xa2,0x20,0x00  # forced-kept: gas re-encodes 'mov    %al,0x20' differently
L_003149:
        call L_0055b5
L_00314c:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_00314d:
        .byte 0xa0,0x57,0x00  # forced-kept: gas re-encodes 'mov    0x57,%al' differently
L_003150:
        .byte 0x12,0x06,0x20,0x00  # forced-kept: gas re-encodes 'adc    0x20,%al' differently
L_003154:
        .byte 0x27  # forced-kept: gas re-encodes 'daa' differently
L_003155:
        .byte 0xa2,0x57,0x00  # forced-kept: gas re-encodes 'mov    %al,0x57' differently
L_003158:
        .byte 0xa0,0x56,0x00  # forced-kept: gas re-encodes 'mov    0x56,%al' differently
L_00315b:
        .byte 0x14,0x00  # forced-kept: gas re-encodes 'adc    $0x0,%al' differently
L_00315d:
        .byte 0x27  # forced-kept: gas re-encodes 'daa' differently
L_00315e:
        .byte 0xa2,0x56,0x00  # forced-kept: gas re-encodes 'mov    %al,0x56' differently
L_003161:
        jmp L_000c33
L_003164:
        call L_0051df
        db "MISS",0x00        # string
L_00316c:
        jmp L_000c33
