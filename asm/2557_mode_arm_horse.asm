# sub_2557 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2557..2574  len 001E B  evidence: seed+reko
# calls: L_000911, L_002826, L_0060c7
# provenance: static (bytes) + live:stepcost — the 2026-10-25 forced-[DS:13] sample set
#           [DS:13] = 0x22 and measured -38 food for one arrow, which is this arm's
#           `jmp L_002826` running. Grade that as observed-under-a-forced-byte, per
#           asm/2626's own caveat: the mode was poked, not boarded.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# RENAMED 2026-10-29 from sub_2557, with the behaviour: the HORSE arm of asm/253B's
#           travel-mode dispatch. asm/2553 reaches here when [DS:13] == 0x22.
#
#           The body is a delay loop (two nested counters over 0x20 with a `call L_000911`
#           inside, the same shape asm/2575 uses on foot) and then `jmp L_002826`, which is
#           asm/2626_food_drain_mounted. So the horse has NO tile rule of its own and pays
#           whatever asm/2626 decides — which is the foot ladder plus two rejects of its
#           own, not 'the same ladder as foot'. See that file.
sub_2557:
L_002757:
        call L_0060c7
L_00275a:
        mov    $0x0,%bh
L_00275c:
        mov    $0xff,%bl
L_00275e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002760:
        mov    $0x0,%bh
L_002762:
        mov    $0x20,%bl
L_002764:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002766:
        dec    %si
L_002767:
        jne L_002766
L_002769:
        mov    $0x10,%bx
L_00276c:
        call L_000911
L_00276f:
        dec    %di
L_002770:
        jne L_002760
L_002772:
        jmp L_002826
