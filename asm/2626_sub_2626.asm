# sub_2626 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2626..2663  len 003E B  evidence: call+reko
# calls: L_00248d, L_002775, L_002804
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2626:
L_002826:
        nop
L_002827:
        stc
L_002828:
        mov    0x55,%al
L_00282b:
        cmc
L_00282c:
        sbb    $0x19,%al
L_00282e:
        das
L_00282f:
        cmc
L_002830:
        mov    %al,0x55
L_002833:
        mov    0x54,%al
L_002836:
        cmc
L_002837:
        sbb    $0x0,%al
L_002839:
        das
L_00283a:
        cmc
L_00283b:
        mov    %al,0x54
L_00283e:
        mov    0x53,%al
L_002841:
        cmc
L_002842:
        sbb    $0x0,%al
L_002844:
        das
L_002845:
        cmc
L_002846:
        mov    %al,0x53
L_002849:
        jb L_00284e
L_00284b:
        jmp L_00248d
L_00284e:
        call L_002775
L_002851:
        cmp    $0xff,%al
L_002853:
        je L_0027ff
L_002855:
        mov    0x29,%al
L_002858:
        and    $0x7f,%al
L_00285a:
        cmp    $0x2,%al
L_00285c:
        je L_0027ff
L_00285e:
        cmp    $0x60,%al
L_002860:
        je L_0027ff
L_002862:
        jmp L_002804
