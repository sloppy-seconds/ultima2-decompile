# sub_090d — mechanical clean (bulk wave); behavior not yet reviewed
# func 090D..092F  len 0023 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_090d:
L_000b0d:
        mov    0x55,%al
L_000b10:
        cmc
L_000b11:
        sbb    $0xa,%al
L_000b13:
        das
L_000b14:
        cmc
L_000b15:
        mov    %al,0x55
L_000b18:
        mov    0x54,%al
L_000b1b:
        cmc
L_000b1c:
        sbb    $0x0,%al
L_000b1e:
        das
L_000b1f:
        cmc
L_000b20:
        mov    %al,0x54
L_000b23:
        mov    0x53,%al
L_000b26:
        cmc
L_000b27:
        sbb    $0x0,%al
L_000b29:
        das
L_000b2a:
        cmc
L_000b2b:
        mov    %al,0x53
L_000b2e:
        jb L_000b33
