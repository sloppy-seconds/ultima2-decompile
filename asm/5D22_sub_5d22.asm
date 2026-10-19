# sub_5d22 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5D22..5D2C  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5d22:
L_005f22:
        mov    $0x0,%cl
L_005f24:
        mov    %cs:0x0(%bp),%ch
L_005f28:
        cmp    $0x0,%ch
L_005f2b:
        je L_005f55
