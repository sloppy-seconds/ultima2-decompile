# sub_41aa — mechanical clean (bulk wave); behavior not yet reviewed
# func 41AA..41D1  len 0028 B  evidence: seed+reko
# strings: "A WIZARD SAYS:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_41aa:
L_0043aa:
        call L_0051df
        db "A WIZARD SAYS:",0x0d,"HEX-E-POO-HEX-ON-YOU!",0x00        # string
