# sub_4209 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4209..4210  len 0008 B  evidence: seed+reko
# calls: L_00174e
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4209:
L_004409:
        stc
L_00440a:
        cmc
L_00440b:
        sbb    $0x80,%al
L_00440d:
        cmc
L_00440e:
        call L_00174e
