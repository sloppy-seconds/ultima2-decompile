# sub_01c4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 01C4..01E0  len 001D B  evidence: seed+reko
# strings: "FANTASY ROLE-PLAYING GAME"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_01c4:
L_0003c4:
        call L_0051df
        db "FANTASY ROLE-PLAYING GAME",0x00        # string
