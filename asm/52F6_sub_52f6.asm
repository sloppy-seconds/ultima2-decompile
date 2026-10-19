# sub_52f6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 52F6..52FF  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_52f6:
L_0054f6:
        dec    %bx
L_0054f7:
        mov    %cs:(%bx,%si),%al
L_0054fa:
        mov    %al,0x246(%bx)
L_0054fe:
        jne L_0054f6
