# not_a_cleric_msg — rejects cleric-only action
# name-evidence: string ' YOU ARE NOT A CLERIC!'
# func 184C..1865  len 001A B  evidence: seed+reko
# strings: " YOU ARE NOT A CLERIC!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
not_a_cleric_msg:
L_001a4c:
        call L_0051df
        db " YOU ARE NOT A CLERIC!",0x00        # string
