# status_torches — status line: torch count
# name-evidence: string 'TORCHES-'
# func 45E9..45F4  len 000C B  evidence: seed+reko
# strings: "TORCHES-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
status_torches:
L_0047e9:
        call L_0051df
        db "TORCHES-",0x00        # string
