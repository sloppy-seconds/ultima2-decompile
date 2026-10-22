# street_guard — guard street response (taxes)
# name-evidence: string 'A GUARD SAYS:' + 'PAY YOUR TAXES'
# func 40E0..4100  len 0021 B  evidence: seed+reko
# strings: "A GUARD SAYS:"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
street_guard:
L_0042e0:
        call L_0051df
        db "A GUARD SAYS:",0x0d,"PAY YOUR TAXES!",0x00        # string
