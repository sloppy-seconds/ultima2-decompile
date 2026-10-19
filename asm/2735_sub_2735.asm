# sub_2735 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2735..2743  len 000F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2735:
L_002935:
        mov    $0x0,%bh
L_002937:
        mov    $0x0,%bl
L_002939:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00293b:
        mov    0x70,%al
L_00293e:
        mov    0x6,%bx
L_002942:
        mov    %al,(%bx,%si)
