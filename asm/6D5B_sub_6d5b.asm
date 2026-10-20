# sub_6d5b — mechanical clean (bulk wave); behavior not yet reviewed
# func 6D5B..6D67  len 000D B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6d5b:
L_006f5b:
        movb   $0x3b,%cs:0x6996
L_006f61:
        movb   $0x67,%cs:0x6997
L_006f67:
        ret
