# sub_1086 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1086..109F  len 001A B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1086:
L_001286:
        nop
L_001287:
        mov    $0x0,%bh
L_001289:
        mov    0x25,%bl
L_00128d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00128f:
        mov    0x1f7(%di),%al
L_001293:
        mov    %al,0x19
L_001296:
        mov    0x217(%di),%al
L_00129a:
        mov    %al,0x1a
L_00129d:
        call L_005417
