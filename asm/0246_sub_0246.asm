# sub_0246 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0246..025C  len 0017 B  evidence: seed+reko
# strings: "ULTIMA ]["
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0246:
L_000446:
        movb   $0x1,0x2f
L_00044b:
        mov    $0xf,%al
L_00044d:
        mov    %al,0x2e
L_000450:
        call L_0051df
        db "ULTIMA ][",0x00        # string
