# sub_40d7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 40D7..40DF  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_40d7:
L_0042d7:
        nop
L_0042d8:
        mov    0x197(%di),%al
L_0042dc:
        cmp    $0x60,%al
L_0042de:
        jne L_004304
