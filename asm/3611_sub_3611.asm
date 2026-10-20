# sub_3611 — mechanical clean (bulk wave); behavior not yet reviewed
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
