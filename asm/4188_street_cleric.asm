# street_cleric — cleric street response
# name-evidence: string 'A CLERIC SAYS:'
# func 4188..41A2  len 001B B  evidence: seed+reko
# strings: "A CLERIC SAYS:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
street_cleric:
L_004388:
        call L_0051df
        db "A CLERIC SAYS:",0x0d,"BELIEVE!",0x00        # string
