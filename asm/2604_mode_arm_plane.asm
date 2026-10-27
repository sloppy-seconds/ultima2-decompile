# sub_2604 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2604..2618  len 0015 B  evidence: seed+reko
# calls: L_002804, L_002826, L_002864
# provenance: static (bytes) + live:flight-launched-live, flight-32-live — both dumps read
#           [DS:13] = 0x26, so the mode this arm gates on is observed; whether the arm
#           itself ran depends on the player walking while mounted, and no capture has
#           recorded that. The forest reject is therefore inferred-from-bytes.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# RENAMED 2026-10-29 from sub_2604, with the behaviour: the PLANE arm of asm/253B's
#           travel-mode dispatch. asm/2545 reaches L_002807 here when [DS:13] == 0x26.
#
#           The body is `call L_002826` (asm/2626, the mounted drain, which itself calls the
#           foot tail and so runs the whole ladder), reject if it returned 0xFF, then
#           `mov 0x29,%al ; and 0x7f ; cmp 0x6 ; je reject`, then accept.
#
#           So the plane's rule is the MOUNTED rule minus forest, and the mounted rule is
#           the foot ladder minus shallow water. It is NOT 'flies over anything except
#           forest', which is what F14 said when this file was read on its own without
#           following the call. The forest reject at runtime 0x2813 is the only tile this
#           arm adds by itself.
#
#           IMPORTANT SCOPE LIMIT, and it is the open question: this arm is the PLANE WALKED
#           ON THE GROUND. While airborne the player is inside asm/38B0's own flight loop,
#           which consults no passability routine at all and charges no food — [DS:13] stays
#           0x26 for both. So 'can the plane cross forest while airborne' is not a question
#           this ladder answers, and the owner's recollection ('plane on land can't traverse
#           forest') is consistent with the rule being the grounded one. Unproven either
#           way; needs the sector-41 capture in docs/needs-gameplay.md.
sub_2604:
L_002804:
        jmp L_002864
L_002806:
        nop
L_002807:
        call L_002826
L_00280a:
        cmp    $0xff,%al
L_00280c:
        je L_0027ff
L_00280e:
        mov    0x29,%al
L_002811:
        and    $0x7f,%al
L_002813:
        cmp    $0x6,%al
L_002815:
        je L_0027ff
L_002817:
        jmp L_002804
