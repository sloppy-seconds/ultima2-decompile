# sub_20eb — mechanical clean (bulk wave); behavior not yet reviewed
# func 20EB..2120  len 0036 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_20eb:
L_0022eb:
        clc
L_0022ec:
        mov    0x2a,%al
L_0022ef:
        adc    0x28,%al
L_0022f3:
        daa
L_0022f4:
        mov    $0x0,%bh
L_0022f6:
        mov    0x28,%bl
L_0022fa:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0022fc:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_0022fe:
        mov    %bl,0x2a
L_002302:
        mov    %al,0x28
L_002305:
        mov    0x29,%al
L_002308:
        adc    0x27,%al
L_00230c:
        daa
L_00230d:
        mov    $0x0,%bh
L_00230f:
        mov    0x27,%bl
L_002313:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002315:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_002317:
        mov    %bl,0x29
L_00231b:
        mov    %al,0x27
L_00231e:
        dec    %di
L_00231f:
        jne L_0022eb
