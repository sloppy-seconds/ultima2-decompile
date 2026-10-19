# sub_5cdd — mechanical clean (bulk wave); behavior not yet reviewed
# func 5CDD..5CDF  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5cdd:
L_005edd:
        dec    %ax
L_005ede:
        jns L_005edd
