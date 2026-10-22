# street_fighter — fighter street response
# name-evidence: string 'A FIGHTER SAYS:'
# func 415F..4180  len 0022 B  evidence: seed+reko
# strings: "A FIGHTER SAYS:"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
street_fighter:
L_00435f:
        call L_0051df
        db "A FIGHTER SAYS:",0x0d,"UGH, ME TOUGH!",0x00        # string
