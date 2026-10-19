# sub_48a7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 48A7..48BB  len 0015 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_48a7:
L_004aa7:
        movb   $0x0,0x2e
L_004aac:
        movb   $0x0,0x54f
L_004ab1:
        movb   $0x28,0x31
L_004ab6:
        mov    $0x0,%bh
L_004ab8:
        mov    $0x0,%bl
L_004aba:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
