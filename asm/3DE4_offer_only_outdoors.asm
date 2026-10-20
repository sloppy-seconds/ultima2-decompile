# offer_only_outdoors — OFFER rejected indoors
# name-evidence: string 'ONLY OUTDOORS!' in cmd_O chain
# func 3DE4..3DF6  len 0013 B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
offer_only_outdoors:
L_003fe4:
        call L_0051df
        db 0x8d,"ONLY OUTDOORS!",0x00        # string
