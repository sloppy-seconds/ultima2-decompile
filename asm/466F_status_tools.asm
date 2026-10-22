# status_tools — status line: tool count
# name-evidence: string 'TOOLS-'
# func 466F..4678  len 000A B  evidence: seed+reko
# strings: "TOOLS-"
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
status_tools:
L_00486f:
        call L_0051df
        db "TOOLS-",0x00        # string
