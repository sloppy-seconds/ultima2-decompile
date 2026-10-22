# street_jester — jester street response
# name-evidence: string 'A JESTER SAYS:'
# func 4108..4124  len 001D B  evidence: seed+reko
# strings: "A JESTER SINGS:"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
street_jester:
L_004308:
        call L_0051df
        db "A JESTER SINGS:",0x0d,"HO HO HO!",0x00        # string
