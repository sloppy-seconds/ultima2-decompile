# sub_5196 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5196..51A3  len 000E B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5196:
L_005396:
        mov    $0x1d,%al
L_005398:
        mov    %al,0x31
L_00539b:
        mov    $0x0,%di
L_00539e:
        mov    $0x17,%si
L_0053a1:
        call L_0053eb
