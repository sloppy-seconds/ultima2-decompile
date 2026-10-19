# sub_0cdc — mechanical clean (bulk wave); behavior not yet reviewed
# func 0CDC..0CED  len 0012 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cdc:
L_000edc:
        mov    $0x0,%bh
L_000ede:
        mov    0x1f,%bl
L_000ee2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ee4:
        mov    %al,0x157(%di)
L_000ee8:
        mov    %al,0x24
L_000eeb:
        call L_0052b3
