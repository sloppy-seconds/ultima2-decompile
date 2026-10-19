# sub_2c19 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2C19..2C25  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2c19:
L_002e19:
        stc
L_002e1a:
        mov    0x177(%di),%al
L_002e1e:
        cmc
L_002e1f:
        sbb    0x1f,%al
L_002e23:
        cmc
L_002e24:
        jae L_002ea4
