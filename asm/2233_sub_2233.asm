# sub_2233 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2233..2259  len 0027 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2233:
L_002433:
        mov    0x1b7(%di),%al
L_002437:
        mov    $0x0,%bh
L_002439:
        mov    $0x0,%bl
L_00243b:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00243d:
        mov    0x6,%bx
L_002441:
        mov    %al,(%bx,%si)
L_002443:
        mov    0x27,%al
L_002446:
        mov    %al,0x23
L_002449:
        mov    %al,0x137(%di)
L_00244d:
        mov    0x28,%al
L_002450:
        mov    %al,0x24
L_002453:
        mov    %al,0x157(%di)
L_002457:
        call L_0052b3
