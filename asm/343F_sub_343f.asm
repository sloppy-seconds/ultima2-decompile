# sub_343f — mechanical clean (bulk wave); behavior not yet reviewed
# func 343F..34B4  len 0076 B  evidence: seed+reko
# strings: "-TOWN"; "-TOWER"
# calls: L_000c33, L_002490, L_0024d5, L_0024fd, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_343f:
L_00363f:
        mov    $0x4,%al
L_003641:
        mov    %al,0x12
L_003644:
        jmp L_000c33
L_003647:
        call L_0051df
        db "-TOWN",0x00        # string
L_003650:
        .byte 0xa0,0x00,0x00  # forced-kept: gas re-encodes 'mov    0x0,%al' differently
L_003653:
        mov    %al,0x5a
L_003656:
        mov    0x1,%al
L_003659:
        mov    %al,0x5b
L_00365c:
        call L_0024fd
L_00365f:
        mov    $0x1f,%al
L_003661:
        mov    %al,0x0
L_003664:
        mov    $0x3e,%al
L_003666:
        mov    %al,0x1
L_003669:
        mov    $0x2,%al
L_00366b:
        mov    %al,0x4a
L_00366e:
        call L_002490
L_003671:
        call L_0024d5
L_003674:
        mov    $0x4,%al
L_003676:
        mov    %al,0x12
L_003679:
        jmp L_000c33
L_00367c:
        call L_0051df
        db "-TOWER",0x00        # string
L_003686:
        .byte 0xa0,0x00,0x00  # forced-kept: gas re-encodes 'mov    0x0,%al' differently
L_003689:
        mov    %al,0x5a
L_00368c:
        mov    0x1,%al
L_00368f:
        mov    %al,0x5b
L_003692:
        call L_0024fd
L_003695:
        mov    $0x0,%al
L_003697:
        mov    %al,0x25
L_00369a:
        mov    %al,0x3
L_00369d:
        mov    $0x1,%al
L_00369f:
        mov    %al,0x2
L_0036a2:
        mov    $0x5,%al
L_0036a4:
        mov    %al,0x0
L_0036a7:
        mov    %al,0x1
L_0036aa:
        mov    $0x4,%al
L_0036ac:
        mov    %al,0x4a
L_0036af:
        call L_002490
L_0036b2:
        jmp L_000c33
