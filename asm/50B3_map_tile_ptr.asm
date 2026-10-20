# map_tile_ptr — address of the current map tile: y(DS:0024)*64 + x(DS:0023) + table DS:0472
# name-evidence: shl 6 of DS:0024, add DS:0023, add word at DS:0472; 26 call sites
# func 50B3..50D7  len 0025 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
map_tile_ptr:
L_0052b3:
        push   %bx
L_0052b4:
        push   %cx
L_0052b5:
        mov    $0x0,%ah
L_0052b7:
        mov    0x24,%al
L_0052ba:
        mov    $0x6,%cl
L_0052bc:
        shl    %cl,%ax
L_0052be:
        mov    $0x0,%bh
L_0052c0:
        mov    0x23,%bl
L_0052c4:
        .byte 0x03,0xd8  # forced-kept: gas re-encodes 'add    %ax,%bx' differently
L_0052c6:
        add    0x472,%bx
L_0052ca:
        mov    %bx,0x6
L_0052ce:
        mov    (%bx),%al
L_0052d0:
        mov    $0x0,%si
L_0052d3:
        pop    %cx
L_0052d4:
        pop    %bx
L_0052d5:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0052d7:
        ret
