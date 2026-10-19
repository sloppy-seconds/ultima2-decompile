# sub_5dcd — mechanical clean (bulk wave); behavior not yet reviewed
# func 5DCD..5DD6  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5dcd:
L_005fcd:
        mov    $0x0,%ax
L_005fd0:
        sub    %cs:0x5da5,%ax
L_005fd5:
        js L_005fde
