# vehicle_frigate — FRIGATE vehicle message branch
# name-evidence: string ' FRIGATE'
# func 3038..3044  len 000D B  evidence: seed+reko
# strings: " FRIGATE"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
vehicle_frigate:
L_003238:
        nop
L_003239:
        call L_0051df
        db " FRIGATE",0x00        # string
