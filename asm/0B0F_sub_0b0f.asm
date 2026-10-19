# sub_0b0f — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B0F..0B24  len 0016 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b0f:
L_000d0f:
        stc
L_000d10:
        mov    $0x0,%al
L_000d12:
        cmc
L_000d13:
        sbb    0x19,%al
L_000d17:
        mov    %al,0x19
L_000d1a:
        stc
L_000d1b:
        mov    $0x0,%al
L_000d1d:
        cmc
L_000d1e:
        sbb    0x1a,%al
L_000d22:
        mov    %al,0x1a
