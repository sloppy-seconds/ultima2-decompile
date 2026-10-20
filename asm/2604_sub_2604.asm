# sub_2604 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2604..2618  len 0015 B  evidence: seed+reko
# calls: L_002804, L_002826, L_002864
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
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
