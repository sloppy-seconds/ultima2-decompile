# monster_damage_apply — apply the rolled damage byte to the selected monster slot
# name-evidence: reached by FALL-THROUGH, not by call or jump — no textual caller
#           exists and no word equal to its runtime address appears anywhere in the
#           image. The live chain is asm/35F3 (store slot index to [DS:20]) ->
#           asm/3603 (call the RNG L_005417) -> asm/3606 (`or $0x20,%al;
#           mov %al,0x1F`, so the damage byte is rand|0x20 — every byte with bit 5 set, floor 32
#           and ceiling 255, NOT 32..63 as this header used to say) ->
#           asm/360E -> here, which rebuilds DI from [DS:20] and `jmp L_002e19`
#           into asm/2C19_monster_hp_subtract. After the subtract returns it tests
#           the site kind (`cmpb $0x4,[DS:4A]`) and, below tower, stamps 0x8 into a
#           map cell via L_0052b3.
# NOT what this was filed as: this is NOT the townsfolk spawn path. It was promoted
#           to "best lead for town NPCs" on the strength of the [DS:4A] test and
#           that was wrong — the site-kind check gates a map stamp, not NPC creation,
#           and the routine takes damage rather than assigning HP. Retracted
#           2026-10-22; see docs/bestiary.md § 6.
# provenance: static, 2026-10-22
# confidence: medium (the fall-through chain and the damage byte are bytes; what the
#           0x8 stamp means is not established)
# label: kept as sub_3611 on purpose — labels are body (CP0)
# func 3611..363A  len 002A B  evidence: seed+reko
# calls: L_002e19, L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3611:
L_003811:
        mov    $0x0,%bh
L_003813:
        mov    0x20,%bl
L_003817:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_003819:
        jmp L_002e19
L_00381c:
        cmpb   $0x4,0x4a
L_003821:
        jae L_00383a
L_003823:
        mov    0x0,%al
L_003826:
        mov    %al,0x23
L_003829:
        mov    0x1,%al
L_00382c:
        mov    %al,0x24
L_00382f:
        call L_0052b3
L_003832:
        mov    $0x8,%al
L_003834:
        mov    0x6,%bx
L_003838:
        mov    %al,(%bx,%si)
L_00383a:
        ret
