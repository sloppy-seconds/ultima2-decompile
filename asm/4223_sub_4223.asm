# sub_4223 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4223..4231  len 000F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4223:
L_004423:
        mov    $0x0,%bh
L_004425:
        mov    0x20,%bl
L_004429:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00442b:
        mov    0x6d,%al
L_00442e:
        cmp    $0x9,%al
L_004430:
        jne L_004446
