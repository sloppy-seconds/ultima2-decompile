# sub_0859 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0859..0863  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0859:
L_000a59:
        dec    %di
L_000a5a:
        mov    %al,0x272(%di)
L_000a5e:
        mov    %al,0x372(%di)
L_000a62:
        jne L_000a59
