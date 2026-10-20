# sub_34e4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 34E4..3524  len 0041 B  evidence: seed+reko
# strings: "-DUNGEON"
# calls: L_000c33, L_002490, L_0024fd, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_34e4:
L_0036e4:
        mov    $0x4,%al
L_0036e6:
        mov    %al,0x12
L_0036e9:
        jmp L_000c33
L_0036ec:
        call L_0051df
        db "-DUNGEON",0x00        # string
L_0036f8:
        .byte 0xa0,0x00,0x00  # forced-kept: gas re-encodes 'mov    0x0,%al' differently
L_0036fb:
        mov    %al,0x5a
L_0036fe:
        mov    0x1,%al
L_003701:
        mov    %al,0x5b
L_003704:
        call L_0024fd
L_003707:
        mov    $0x0,%al
L_003709:
        mov    %al,0x25
L_00370c:
        mov    %al,0x3
L_00370f:
        mov    $0x1,%al
L_003711:
        mov    %al,0x2
L_003714:
        mov    $0x5,%al
L_003716:
        mov    %al,0x0
L_003719:
        mov    %al,0x1
L_00371c:
        mov    %al,0x4a
L_00371f:
        call L_002490
L_003722:
        jmp L_000c33
