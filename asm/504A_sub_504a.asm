# sub_504a — mechanical clean (bulk wave); behavior not yet reviewed
# func 504A..5056  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_504a:
L_00524a:
        incb   0x2e
L_00524e:
        mov    0x31,%al
L_005251:
        cmp    0x2e,%al
L_005255:
        jb L_00520d
