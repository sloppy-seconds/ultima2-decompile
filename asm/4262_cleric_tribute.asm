# cleric_tribute — cleric demands 50 GP
# name-evidence: string 'FIRST MY 50 G.P. TRIBUTE!'
# func 4262..4280  len 001F B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cleric_tribute:
L_004462:
        call L_0051df
        db 0x8d,"FIRST MY 50 G.P. TRIBUTE!",0x8d,0x00        # string
