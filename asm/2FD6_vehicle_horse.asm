# vehicle_horse — HORSE vehicle message branch
# name-evidence: string ' HORSE'
# func 2FD6..2FF5  len 0020 B  evidence: seed+reko
# strings: " HORSE"
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
vehicle_horse:
L_0031d6:
        call L_0051df
        db " HORSE",0x00        # string
L_0031e0:
        .byte 0xb0,0x08  # forced-kept: gas re-encodes 'mov    $0x8,%al' differently
L_0031e2:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_0031e4:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_0031e6:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0031e8:
        .byte 0x8b,0x9d,0x06,0x00  # forced-kept: gas re-encodes 'mov    0x6(%di),%bx' differently
L_0031ec:
        mov    %al,(%bx)
L_0031ee:
        mov    $0x22,%al
L_0031f0:
        mov    %al,0x13
L_0031f3:
        jmp L_000c33
