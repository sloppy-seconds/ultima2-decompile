# yell_no_response — YELL at nothing useful
# name-evidence: string 'FUNNY, NO RESPONSE!' in cmd_Y chain
# func 40A6..40BC  len 0017 B  evidence: seed+reko
# strings: "FUNNY, NO RESPONSE!"
# calls: L_0051df (str_out)
# provenance: live:airport (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
yell_no_response:
L_0042a6:
        call L_0051df
        db "FUNNY, NO RESPONSE!",0x00        # string
