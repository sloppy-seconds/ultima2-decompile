# combat_thief_steal — thief steals something mid-combat
# name-evidence: string 'A THIEF STOLE SOMETHING!'
# corroboration 2026-10-22: Gamer Corner's Thief tile is pixel-identical to our art
#   0x3F (see bestiary/bestiary.tsv), and both sources give "can steal any item".
#   Note the codex lists Thief as both a wandering monster and a townsfolk NPC, so
#   the string's 'A THIEF' agrees with a creature, not only the player class at
#   file 0x50FE. External claim; changes no name.
# func 0FCD..1012  len 0046 B  evidence: call+reko
# strings: "A THIEF STOLE SOMETHING!"
# calls: L_0051df (str_out), L_005417
# provenance: live:castle-03-live — 'A THIEF STOLE SOMETHING!' is in the executed
#           print set, and the BCD decrement at runtime 0x0FE7 is on the executed path.
# RETRACTED 2026-10-22: this header previously claimed the routine "tests the type against
#   0x40 at file 0x1244, so the thief is monster type 0x40". Both halves are wrong.
#   Re-read against the bytes: there is exactly ONE `cmp $0x40,%al` in this function, at
#   file 0x11D1 (runtime 0x0FD1) -- 0x1244 is outside the declared span. It does not
#   compare a monster type. The full routine is:
#
#     call L_005417          ; random
#     cmp $0x40,%al          ; rand < 64 of 256 -> ~25% chance of attempting a theft
#     jb  steal
#     ret                    ; else no theft, silently
#   steal:
#     call L_005417          ; random
#     and $0xf,%ax           ; slot index 0..15
#     mov 0xd6(%di),%al      ; item array [DS:D6 + slot];  DS:D6 is slot 0 (the RING,
#     or %al,%al             ;   per asm/0E70, asm/0EC2, asm/0F48 and asm/24B5)
#     je  done               ; EMPTY SLOT -> nothing taken and NOTHING PRINTED
#     stc; sbb $0x1,%al; das; cmc   ; packed-decimal decrement by 1
#     mov %al,0xd6(%di)
#     print "A THIEF STOLE SOMETHING!"
#   done: ret
#
#   So 0x40 here is a PROBABILITY THRESHOLD, not a type. Note also that 0x40 is the
#   empty-slot sentinel in the monster record ([DI+0x197]) -- a second, unrelated use of
#   the same byte, and the likely origin of the original confusion.
#   Which monster reaches this routine is NOT decided here. The caller asm/0AD3 dispatches
#   on the kind index [DI+0x1B7]; this function never reads a monster record.
#   Engine consequence: a failed theft is SILENT, so a reimplementation that prints on
#   every thief turn will not match.
# notes: theft is PERMANENT. Measured over 3000 recorded turns in the sector-00
#           fight: eight items went 1 -> 0 (RING, GEM, ANKH, TRI-LITHIUM,
#           BLUE TASSLE, BOOTS, GREEN GEM, SKULL KEY) and none ever returned. The
#           kill that ended the fight paid HELM 1 -> 2 and gold +15, i.e. the same
#           random drop as any other kill (compare the STAFF 1 -> 2 / gold +17 kill
#           earlier in the same run). There is no restore-stolen-goods path.
#           Consequence for the engine: a stolen item must be removed from the
#           item array, not flagged, because the resist gates read that array live
#           (see asm/0E70, asm/0EC2, asm/0F48 and asm/24B5).
# confidence: high for the mechanics (roll threshold, random slot, BCD decrement, silence
#   on empty slot, permanence -- all read from the bytes and corroborated by live theft);
#   LOW for any mapping from this routine to a specific monster type, because none exists
#   in this function.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_thief_steal:
L_0011cd:
        nop
L_0011ce:
        call L_005417
L_0011d1:
        cmp    $0x40,%al
L_0011d3:
        jb L_0011d6
L_0011d5:
        ret
L_0011d6:
        nop
L_0011d7:
        call L_005417
L_0011da:
        .byte 0x25,0x0f,0x00  # forced-kept: gas re-encodes 'and    $0xf,%ax' differently
L_0011dd:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_0011df:
        mov    0xd6(%di),%al
L_0011e3:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0011e5:
        je L_001212
L_0011e7:
        stc
L_0011e8:
        mov    0xd6(%di),%al
L_0011ec:
        cmc
L_0011ed:
        sbb    $0x1,%al
L_0011ef:
        das
L_0011f0:
        cmc
L_0011f1:
        mov    %al,0xd6(%di)
L_0011f5:
        call L_0051df
        db "A THIEF STOLE SOMETHING!",0x8d,0x00        # string
L_001212:
        ret
